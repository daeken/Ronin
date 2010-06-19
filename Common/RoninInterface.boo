namespace Ronin

import System

enum Suit:
	Club
	Diamond
	Heart
	Spade

enum Rank:
	Two
	Three
	Four
	Five
	Six
	Seven
	Eight
	Nine
	Ten
	Jack
	Queen
	King
	Ace
	Hidden

public abstract class RoninTableModel(MarshalByRefObject):
	public virtual Name as string:
		get:
			pass
	
	public Controller as IBotTableModel

public interface IBot:
	def Table(model as RoninTableModel)

public interface IBotTableModel:
	def DealTableCard(suit as Suit, rank as Rank)
	def DealPlayerCard(suit as Suit, rank as Rank, player as int)
	def HandCompleted()
	def Terminated()
	def ActionOn(player as int)

public class RoninInterface(MarshalByRefObject):
	public static Bot as IBot
	
	def Ready():
		print 'Ready'
	
	def Print(msg as string):
		print 'Msg:', msg
	
	def RegisterModel(model as RoninTableModel):
		Bot.Table(model)
