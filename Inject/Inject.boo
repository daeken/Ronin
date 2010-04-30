namespace Ronin.Inject

import EasyHook
import Ronin
import System
import System.Runtime.InteropServices

class Inject(EasyHook.IEntryPoint):
	Ronin as RoninInterface
	
	def constructor(context as RemoteHooking.IContext, channel as string):
		Ronin = RemoteHooking.IpcConnectClient [of RoninInterface](channel)
		
		Ronin.Ping()
	
	def Run(context as RemoteHooking.IContext, _channel as string):
		RemoteHooking.WakeUpProcess()
