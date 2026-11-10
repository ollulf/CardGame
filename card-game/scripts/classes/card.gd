extends RefCounted
class_name Card

var suit : Suit
var is_trump : bool:
	get:
		return get_is_trump()
var is_played : bool
var rank : int
var base_rank : int
var buff_parts : Array[Dictionary] = []
var owner : Owner = Owner.NONE


enum Owner {
	HUMAN,
	AI_1,
	AI_2,
	NONE
}

enum Suit {
	DIAMONDS,
	HEARTS,
	SPADES,
	CLUBS,
	ALK,
	SMOKE
}

func _init(suit: Suit, rank: int, owner : Owner, is_played: bool):
	self.suit = suit
	self.rank = rank
	base_rank = rank
	self.owner = owner
	self.is_played = is_played

signal values_changed()
signal removed()

func is_suit(suit : Suit) -> bool:
	return self.suit == suit

func is_higher_than(card : Card) -> bool:
	return rank > card.rank

func get_is_trump() -> bool:
	return suit == Suit.ALK or suit == Suit.SMOKE or suit == CardManager.trump_suit

func apply_modifiers():
	values_changed.emit()

func string_info() -> String:
	return str(Suit.keys()[suit], " - ", rank, " (", Owner.keys()[owner], ")")

func remove():
	removed.emit()
