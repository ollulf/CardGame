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
var effect : CardEffect.Id = CardEffect.Id.NONE


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

func _init(suit: Suit, rank: int, owner : Owner, is_played: bool, effect : CardEffect.Id = CardEffect.Id.NONE):
	self.suit = suit
	self.effect = effect
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

func has_effect() -> bool:
	return effect != CardEffect.Id.NONE

func copy_for(new_owner: Owner) -> Card:
	return Card.new(suit, base_rank, new_owner, false, effect)

func get_is_trump() -> bool:
	return suit == Suit.ALK or suit == Suit.SMOKE or suit == CardManager.trump_suit

func apply_modifiers():
	values_changed.emit()

func string_info() -> String:
	var effect_text := " [%s]" % CardEffect.word(effect) if has_effect() else ""
	return str(Suit.keys()[suit], " - ", rank, effect_text, " (", Owner.keys()[owner], ")")

func remove():
	removed.emit()
