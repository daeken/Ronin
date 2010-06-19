namespace Ronin.Inject

import EasyHook
import QtWrapper
import Ronin
import System
import System.Collections
import System.Collections.Generic
import System.Diagnostics
import System.Runtime.InteropServices
import System.Runtime.Remoting.Channels
import System.Runtime.Remoting.Channels.Ipc
import System.Threading

class Window:
	public Handle as IntPtr
	public Widget as IntPtr
	public Initialized = false
	
	def constructor(handle as IntPtr):
		Handle = handle
		
		Widget = Inject.Script.WidgetFromHandle(Handle)
	
	def Initialize():
		Initialized = true
		if Widget != IntPtr.Zero:
			Inject.Script.Invoke('gotWindow', (cast(object, Widget), ))

class TableModel(RoninTableModel):
	Model as QObjectWrapper
	Ronin as RoninInterface
	
	Name as string:
		get:
			return Model['plaingametiltle']
	
	[extension]
	static def ToMoney(variant as Variant):
		return variant.ToInt() * 0.01
	
	def constructor(model as QObjectWrapper, ronin as RoninInterface):
		Model = model
		Ronin = ronin
		Model.Connect('evTblDealCard(ECardSuit,ECardRank,quint8,uint,uint,uint)', Deal)
		Model.Connect('evTblHandComplete(quint64,quint32)') do(unk, tableHandId as int):
			if tableHandId != -1:
				Controller.HandCompleted()
		Model.Connect('evModelTerminated()') do():
			Controller.Terminated()
		Model.Connect('evTblSeatActivate(quint8,bool,bool)') do(player as int, action as bool, unk as bool):
			if action:
				Controller.ActionOn(player)
		Model.Connect('evTblBalanceChanged(MONEY,bool,qint8,MONEY,MONEY,quint8)') do(foo as Variant, bar, baz, hax as Variant, zomg as Variant, blah):
			Ronin.Print('Balance changed:')
			Ronin.Print('{0} {1} {2} {3} {4} {5}' % (foo.ToMoney(), bar, baz, hax.ToMoney(), zomg.ToMoney(), blah))
		Model.Connect('evTblTotalBalanceChanged(MONEY,bool)') do(money as Variant, blah as bool):
			Ronin.Print('Total balance changed: {0} {1}' % (money.ToMoney(), blah))
		Ronin.RegisterModel(self)
	
	def Deal(suit_ as Variant, rank_ as Variant, which as int, showing, whichCard, cardCount):
		suit = cast(Suit, suit_.ToInt())
		rank = cast(Rank, rank_.ToInt())
		
		if which == 0:
			Controller.DealTableCard(suit, rank)
		else:
			Controller.DealPlayerCard(suit, rank, which)

class Inject(EasyHook.IEntryPoint):
	CurProcess as Process
	public static Ronin as RoninInterface
	Windows = List [of Window]()
	public static Script as QtScript
	
	def constructor(context as RemoteHooking.IContext, channel as string):
		CurProcess = Process.GetCurrentProcess()
		Ronin = RemoteHooking.IpcConnectClient [of RoninInterface](channel)
		
		properties = Hashtable()
		properties.Add('name', 'client')
		properties.Add('portName', 'client')
		properties.Add('typeFilterLevel', 'Full')
		channel_ = IpcChannel(
				properties,
				System.Runtime.Remoting.Channels.BinaryClientFormatterSinkProvider(properties, null), 
				System.Runtime.Remoting.Channels.BinaryServerFormatterSinkProvider(properties, null)
			)
		ChannelServices.RegisterChannel(channel_, false)
	
	[DllImport('user32.dll')]
	static def EnumWindows(callback as callable(IntPtr, IntPtr) as bool, lparam as IntPtr):
		pass
	[DllImport('user32.dll')]
	static def GetWindowThreadProcessId(hwnd as IntPtr, ref pid as int) as int:
		pass
	def ScanWindows():
		found = List [of IntPtr]()
		
		def each(hwnd as IntPtr, lparam as IntPtr) as bool:
			pid as int
			GetWindowThreadProcessId(hwnd, pid)
			if pid == CurProcess.Id:
				found.Add(hwnd)
			return true
		EnumWindows(each, IntPtr.Zero)
		
		i = 0
		while i < Windows.Count:
			if not found.Contains(Windows[i].Handle):
				Windows.RemoveAt(i)
				continue
			if not Windows[i].Initialized:
				Windows[i].Initialize()
			found.Remove(Windows[i].Handle)
			i += 1
		
		for elem in found:
			window = Window(elem)
			Windows.Add(window)
	
	def GetState():
		pass
	
	[UnmanagedFunctionPointer(CallingConvention.Cdecl)]
	callable DExec() as int
	
	[DllImport('QtGui4.dll', CallingConvention: CallingConvention.Cdecl, EntryPoint: '?exec@QApplication@@SAHXZ')]
	static def Exec() as int:
		pass
	
	static Execing as bool
	static def ExecHooker() as int:
		Execing = true
		
		return Exec()
	
	ExecHook as LocalHook
	def Run(context as RemoteHooking.IContext, _channel as string):
		ExecHook = LocalHook.Create(
				LocalHook.GetProcAddress('QtGui4.dll', '?exec@QApplication@@SAHXZ'), 
				DExec(ExecHooker), 
				self
			)
		ExecHook.ThreadACL.SetExclusiveACL((0, ))
		Execing = false
		RemoteHooking.WakeUpProcess()
		
		while not Execing:
			pass
		
		Ronin.Ready()
		RealRun()
	
	def RealRun():
		Script = QtScript()
		Script.SetupPatches()
		
		Script.ExposeFunction('log') do(obj as object) as object:
			Ronin.Print(obj.ToString())
			return obj
		
		Script.Evaluate("""
				function dump(obj) {
					log('Object: ' + obj.toString());
					log('Proto: ' + obj.__proto__);
					log('Parent: ' + parentOf(obj));
					
					try {
						var properties = [];
						var signals = [];
						var slots = [];
						var funcs = [];
						for(var name in obj) {
							if(name.indexOf('(') == -1)
								properties[properties.length] = name;
							else if(name.substring(0, 2) == 'ev')
								signals[signals.length] = name;
							else if(name.substring(0, 2) == 'on')
								slots[slots.length] = name;
							else
								funcs[funcs.length] = name;
						}
						
						function printList(name, list) {
							if(list.length == 0)
								return;
							var ret = name + ': ';
							for(var i = 0; i < list.length; ++i)
								ret += list[i].toString() + ', ';
							log(ret.substring(0, ret.length - 2));
						}
						printList('Properties', properties);
						printList('Signals', signals);
						printList('Slots', slots);
						printList('Functions', funcs);
						
						if(obj.findChildren != undefined)
							printList('Children', obj.findChildren());
					} catch(e) {
						log('Error... ' + e.toString());
					}
				}
				
				function gotWindow(win) {
					if(win.gameix != undefined)
						gotGame(win);
				}
				
				function gotGame(win) {
					log('Game! ' + win.plaingamename);
					
					var model = findModel(win);
					gotModel(model);
				}
				
				function findModel(win) {
					return signalsForSlot(win, 'onTblDealCard(ECardSuit,ECardRank,quint8,uint,uint,uint)')[0][0];
				}
			""")
		
		foo as TableModel
		Script.ExposeFunction('gotModel') do(model as QObjectWrapper):
			foo = TableModel(model, Ronin)
		
		runs = 0
		while true:
			if runs == 0:
				ScanWindows()
			Script.ProcessEvents()
			Thread.Sleep(100)
			runs = (runs + 1) % 10
