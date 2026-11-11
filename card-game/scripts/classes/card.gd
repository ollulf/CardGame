extends RefCounted
class_name Card

var suit : Suit
var is_trump : bool:
	get:
		return get_is_trump()
var is_played : bool
var rank : int
var base_rank : int
var printed_rank : int
var buff_parts : Array[Dictionary] = []
var owner : Owner = Owner.NONE
var effect : CardEffect.Id = CardEffect.Id.NONE
var stamp : CardStamp.Id = CardStamp.Id.NONE


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

func _init(suit: Suit, rank: int, owner : Owner, is_played: bool, effect : CardEffect.Id = CardEffect.Id.NONE, stamp : CardStamp.Id = CardStamp.Id.NONE):
	self.suit = suit
	self.effect = effect
	self.stamp = stamp
	printed_rank = rank
	base_rank = CardStamp.apply_rank(stamp, rank)
	self.rank = base_rank
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

func has_stamp() -> bool:
	return stamp != CardStamp.Id.NONE

func is_colorless() -> bool:
	return stamp == CardStamp.Id.COLORLESS

func draws_first() -> bool:
	return stamp == CardStamp.Id.DRAW_FIRST

func matches_suit(lead_suit: int) -> bool:
	if is_colorless():
		return true
	return lead_suit >= 0 and suit == lead_suit

func set_stamp(new_stamp: CardStamp.Id) -> void:
	stamp = new_stamp
	base_rank = CardStamp.apply_rank(stamp, printed_rank)
	rank = base_rank
	buff_parts = []
	values_changed.emit()

func copy_for(new_owner: Owner) -> Card:
	return Card.new(suit, printed_rank, new_owner, false, effect, stamp)

func get_is_trump() -> bool:
	if is_colorless():
		return false
	return suit == Suit.ALK or suit == Suit.SMOKE or suit == CardManager.trump_suit

func apply_modifiers():
	values_changed.emit()

func string_info() -> String:
	var effect_text := " [%s]" % CardEffect.word(effect) if has_effect() else ""
	var stamp_text := " {%s}" % CardStamp.display_name(stamp) if has_stamp() else ""
	return str(Suit.keys()[suit], " - ", rank, effect_text, stamp_text, " (", Owner.keys()[owner], ")")

func remove():
	removed.emit()
