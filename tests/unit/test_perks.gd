extends TestCase
## Permanent upgrades.


func test_every_perk_describes_each_of_its_ranks() -> void:
	for id: String in Perks.IDS:
		var perk: Perks.PerkDef = Perks.get_def(id)
		for i: int in perk.costs.size():
			expect_match(perk.effect(i + 1), "\\d", id)
	expect_eq(Perks.get_def("capital").effect(2), "+$80 starting money")
	expect_eq(Perks.get_def("engineering").effect(1), "Towers and upgrades 6% cheaper")


func test_no_perks_means_no_modifiers() -> void:
	var m: Perks.Modifiers = Perks.modifiers_from({})
	expect_eq(m.money, 0)
	expect_eq(m.lives, 0)
	expect_eq(m.cost_multiplier, 1.0)
	expect_eq(m.damage_multiplier, 1.0)


func test_ranks_scale_the_modifiers() -> void:
	var m: Perks.Modifiers = Perks.modifiers_from({"capital": 3, "fortify": 2, "engineering": 2, "firepower": 3})
	expect_eq(m.money, 120)
	expect_eq(m.lives, 10)
	expect_eq(m.cost_multiplier, 1 - 0.12)
	expect_eq(m.damage_multiplier, 1 + 0.24)
