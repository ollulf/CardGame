extends RefCounted
class_name Card

var suit : Suit
var is_trump : bool
var is_played : bool
var rank : int
var owner : Owner = Owner.NONE


enum Owner {
	NONE,
	HUMAN,
	AI_1,
	AI_2
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
	self.owner = owner
	self.is_played = is_played
	is_trump = get_is_trump()

signal values_changed()
signal removed()

func is_suit(suit : Suit) -> bool:
	return self.suit == suit

func is_higher_than(card : Card) -> bool:
	return rank > card.rank

func get_is_trump() -> bool:
	return suit == Suit.ALK or suit == Suit.SMOKE

func apply_modifiers():
	values_changed.emit()

func remove():
	removed.emit()
	call_deferred("free")
