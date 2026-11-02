class_name RoguelikeCard
extends RefCounted
## A reward offered after a stage. Knows how to describe itself to the
## player and how to change the run when picked.

enum Kind { CHARGES, NEW_TOOL, RECRUIT, RELIC, REVIVE }

var kind: Kind = Kind.CHARGES
## Tool id (CHARGES, NEW_TOOL), character id (RECRUIT) or relic id (RELIC).
var subject: String = ""
## Charges (CHARGES, NEW_TOOL), or the level the relic goes to (RELIC; 1 when
## not given).
var amount := 0


static func make(card_kind: Kind, card_subject: String = "", card_amount: int = 0) -> RoguelikeCard:
	var card := RoguelikeCard.new()
	card.kind = card_kind
	card.subject = card_subject
	card.amount = card_amount
	return card


func get_title() -> String:
	match kind:
		Kind.CHARGES:
			return "+%d %s" % [amount, SkillManager.get_display_name(subject)]
		Kind.NEW_TOOL:
			return SkillManager.get_display_name(subject)
		Kind.RECRUIT:
			return "Recrutar %s" % RoguelikeCharacters.get_display_name(StringName(subject))
		Kind.RELIC:
			return RoguelikeRelics.get_title_at(StringName(subject), get_relic_level())
		Kind.REVIVE:
			return "Pena da fênix"
	return ""


## The level a relic card takes its relic to.
func get_relic_level() -> int:
	return maxi(amount, 1)


func get_description() -> String:
	match kind:
		Kind.CHARGES:
			return "Mais %d cargas para uma ferramenta que você já tem." % amount
		Kind.NEW_TOOL:
			return "Ferramenta nova, com %d cargas. Barra cheia: sai a usada há mais tempo." % amount
		Kind.RECRUIT:
			return "Um boneco a mais na tropa. %s" % RoguelikeCharacters.get_ability(StringName(subject))
		Kind.RELIC:
			return "Para o resto da run (nível %s). %s" % [RoguelikeRelics.roman(get_relic_level()), RoguelikeRelics.get_effect(StringName(subject), get_relic_level())]
		Kind.REVIVE:
			return "Traz de volta o último boneco perdido (ou o próximo a cair)."
	return ""


## A shorter description that fits the card's text panel; the full one is
## the card's tooltip.
func get_short_description() -> String:
	match kind:
		Kind.CHARGES:
			return "Cargas."
		Kind.NEW_TOOL:
			return "Nova, %d cargas." % amount
		Kind.RECRUIT:
			return RoguelikeCharacters.get_short_ability(StringName(subject))
		Kind.RELIC:
			return RoguelikeRelics.get_effect(StringName(subject), get_relic_level())
		Kind.REVIVE:
			return "Traz de volta o último boneco perdido."
	return ""


## Which card frame it is drawn in (assets/sprites/ui/cards/card_<family>).
func get_frame_family() -> String:
	match kind:
		Kind.RECRUIT:
			return "recruit"
		Kind.RELIC:
			return "relic"
		Kind.REVIVE:
			return "rescue"
	return "tool"


## The picture in the card's window: the character's portrait, the relic's
## or the phoenix feather's illustration, or the tool's icon.
func get_art_path() -> String:
	const CARDS_DIR := "res://assets/sprites/ui/cards/"
	match kind:
		Kind.RECRUIT:
			return CARDS_DIR + "character_%s.png" % subject
		Kind.RELIC:
			return CARDS_DIR + "relic_%s.png" % subject
		Kind.REVIVE:
			return CARDS_DIR + "rescue_phoenix.png"
	return UiStyle.ICON_PATH % subject


## Icon id for UiStyle.icon(); "" when the card draws no tool icon.
func get_icon_id() -> String:
	match kind:
		Kind.CHARGES, Kind.NEW_TOOL:
			return subject
		Kind.RELIC:
			return RoguelikeRelics.get_icon(StringName(subject))
	return ""


## Colour of the card's banner: the character's colour for recruits.
func get_accent() -> Color:
	match kind:
		Kind.RECRUIT:
			return RoguelikeCharacters.get_colour(StringName(subject))
		Kind.RELIC:
			return Color(0.95, 0.75, 0.25)
		Kind.REVIVE:
			return Color(0.95, 0.35, 0.4)
	return Color(0.55, 0.75, 0.95)


## Coins it costs in the shop: a few for charges, more for whatever changes
## the run for good.
func get_price() -> int:
	match kind:
		Kind.CHARGES:
			return 3
		Kind.NEW_TOOL:
			return 6
		Kind.REVIVE:
			return 8
		Kind.RECRUIT:
			return 10
		Kind.RELIC:
			# Dearer at each level.
			return 12 + 6 * (get_relic_level() - 1)
	return 0


func apply(state: RoguelikeRunState) -> void:
	match kind:
		Kind.CHARGES, Kind.NEW_TOOL:
			state.inventory.add_charges(subject, amount)
		Kind.RECRUIT:
			state.recruit(StringName(subject))
		Kind.RELIC:
			state.add_relic(StringName(subject))
		Kind.REVIVE:
			state.revive_tokens += 1
			state.use_revive_tokens()
