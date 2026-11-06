class_name DialogueLines

const LINES := [
	{"when": "game_start", "lines": [
		[1, "Cards down, *smokes* out."],
		[2, "Deal me in."],
	]},
	{"when": "after_turns", "count": 2, "lines": [[1, "Nine of hearts? *Bold.*"]]},
	{"when": "every_turns", "count": 3, "lines": [[2, "You cough when you *bluff.*"]]},
	{"when": "after_rounds", "count": 1, "lines": [[2, "That's one round gone."]]},
	{"when": "between_rounds", "lines": [[1, "Light up. *Next round.*"]]},
	{"when": "game_over", "lines": [[1, "That's it. *Out of lives.*"]]},
]
