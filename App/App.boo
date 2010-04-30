namespace Ronin

import EasyHook
import System.Diagnostics
import System.Runtime.Remoting

class Ronin:
	def constructor():
		Config.Register(
				'Ronin, bot.', 
				'Obj/Ronin.exe', 
				'Obj/Ronin.Inject.dll', 
				'Obj/Ronin.Common.dll'
			)
		
		channelName as string
		RemoteHooking.IpcCreateServer [of RoninInterface](channelName, WellKnownObjectMode.SingleCall)
		pid as int
		RemoteHooking.CreateAndInject(
				'C:\\Program Files (x86)\\Full Tilt Poker\\FullTiltPoker.exe', 
				'', 
				'Obj/Ronin.Inject.dll', 
				'Obj/Ronin.Inject.dll', 
				pid, 
				channelName
			)
		
		try:
			Process.GetProcessById(pid).WaitForExit()
		except:
			return

Ronin()
