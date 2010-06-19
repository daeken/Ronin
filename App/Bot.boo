namespace Ronin

import System
import System.Collections.Generic

struct Card:
	public Suit as Suit
	public Rank as Rank
	
	public def ToShortString() as string:
		if Rank == Rank.Hidden:
			return 'xx'
		
		ret as string
		rank = cast(int, Rank)
		if rank < 8:
			ret = '{0}' % (rank + 2, )
		elif Rank == Rank.Ten:
			ret = 'T'
		elif Rank == Rank.Jack:
			ret = 'J'
		elif Rank == Rank.Queen:
			ret = 'Q'
		elif Rank == Rank.King:
			ret = 'K'
		elif Rank == Rank.Ace:
			ret = 'A'
		
		if Suit == Suit.Heart:
			ret += 'h'
		elif Suit == Suit.Club:
			ret += 'c'
		elif Suit == Suit.Diamond:
			ret += 'd'
		elif Suit == Suit.Spade:
			ret += 's'
		
		return ret

class BotTableModel(MarshalByRefObject, IBotTableModel):
	Table as BotTable
	Model as RoninTableModel
	
	TableCards as (Card) = array(Card, 5)
	CardsDealt = 0
	
	def constructor(table as BotTable, model as RoninTableModel):
		Table = table
		Model = model
		Model.Controller = self
	
	def HandCompleted():
		CardsDealt = 0
		print 'New hand'
	
	def Terminated():
		Table.Terminate()
	
	def DealTableCard(suit as Suit, rank as Rank):
		TableCards[CardsDealt] = Card(Suit: suit, Rank: rank)
		CardsDealt += 1
		
		ret = 'Table cards: '
		for i in range(CardsDealt):
			ret += '{0} ' % (TableCards[i].ToShortString(), )
		print ret
	
	def DealPlayerCard(suit as Suit, rank as Rank, player as int):
		print 'Player card: {0} {1} {2}' % (suit, rank, player)
	
	def ActionOn(player as int):
		pass

class BotTable:
	Model as BotTableModel
	Bot as Bot
	
	def constructor(bot as Bot, model as RoninTableModel):
		Bot = bot
		Model = BotTableModel(self, model)
	
	def Terminate():
		Bot.RemoveTable(self)

class Bot(IBot):
	Tables = List [of BotTable]()
	
	def Table(model as RoninTableModel):
		Tables.Add(BotTable(self, model))
	
	def RemoveTable(table as BotTable):
		Tables.Remove(table)
