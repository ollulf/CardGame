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

signal values_changed()
signal removed()

func _init() -> void:
	is_trump = get_is_trump()

func get_is_trump() -> bool:
	return suit == Suit.ALK or suit == Suit.SMOKE

func apply_modifiers():
	values_changed.emit()

func remove_self():
	removed.emit()
