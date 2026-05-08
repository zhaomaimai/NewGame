# version: C5_v1
# last_modified_cycle: C5
# ═══════════════════════════════════════════════════════════════════
# InternalManager - Internal Affairs Manager
# ═══════════════════════════════════════════════════════════════════
# Functions：
#   1. Execute 6 command types
#   2. 3 commands per city per turn
#   3. Track command costs and value changes
# ═══════════════════════════════════════════════════════════════════
# Interface：
#   execute_command(city_id, cmd_type) → Dictionary
#     Returns: {success, changes: {field: delta, gold: delta}, message}
# ═══════════════════════════════════════════════════════════════════
# Deps: GameState, RandomManager, DebugSystem
# ═══════════════════════════════════════════════════════════════════

extends Node


## 每城每回合最大指令次数
const MAX_COMMANDS_PER_TURN := 3

## 假数据：政治力/统帅力（C6接入武将后替换为实际值）
const DEFAULT_POLITICS := 50
const DEFAULT_LEADERSHIP := 50


## Execute an internal command
# @param city_id:  目标City ID
# @param cmd_type: Command type
#   "agriculture" — 農業開發: 农业+15~18, 金-30
#   "commerce"    — 商業開發: 商业+20~25, 金-30
#   "security"    — Security: 治安+10~13, 金-20
#   "recruit"     — 兵士徴募: 士兵+1500~1700+随机, 金-50
#   "train"       — 兵士訓練: 训练+10~13, 金-10
#   "trade"       — 食糧売買: 金↔粮 (买入价1:3, 卖出价3:1)
# @returns Dictionary: {success, changes, message}
#   success: bool   — Success flag
#   changes: Dictionary — Value changes {field: delta, ...}
#   message: String — Result message
func execute_command(city_id: int, cmd_type: String) -> Dictionary:
	# 检查指令次数
	var count_key := "city.internal_count"
	var counts: Dictionary = GameState.get_data(count_key, {})
	var used: int = counts.get(str(city_id), 0)
	if used >= MAX_COMMANDS_PER_TURN:
		return {
			"success": false,
			"changes": {},
			"message": "本回合指令次数已用完（上限%d次）" % MAX_COMMANDS_PER_TURN
		}

	# 获取城市数据
	var cities: Array = GameState.get_data("city.list", [])
	var city: Dictionary
	for c in cities:
		if int(c.id) == city_id:
			city = c
			break
	if city.is_empty():
		return {"success": false, "changes": {}, "message": "城市不存在"}

	# 检查是否满足前置条件
	var result: Dictionary = _check_prerequisites(city, cmd_type)
	if not result.get("success", true):
		return result

	# 执行指令
	var changes: Dictionary = {}
	match cmd_type:
		"agriculture":
			changes = _cmd_agriculture(city)
		"commerce":
			changes = _cmd_commerce(city)
		"security":
			changes = _cmd_security(city)
		"recruit":
			changes = _cmd_recruit(city)
		"train":
			changes = _cmd_train(city)
		"trade", "trade_buy", "trade_sell":
			changes = _cmd_trade(cmd_type, city)
		_:
			return {"success": false, "changes": {}, "message": "未知指令: " + cmd_type}

	# 扣除金钱
	var gold_cost: int = abs(changes.get("gold", 0))
	if gold_cost > 0:
		city.gold = maxi(0, int(city.get("gold", 0)) - gold_cost)

	# 写回数据
	GameState.set_data("city.list", cities)
	counts[str(city_id)] = used + 1
	GameState.set_data(count_key, counts)

	# 日志
	DebugSystem.print_dbg("[INTERNAL] %s city=%d %s" % [cmd_type, city_id, _changes_string(changes)])

	return {
		"success": true,
		"changes": changes,
		"message": _build_message(cmd_type, changes)
	}


## Check prerequisites (gold, value caps)
func _check_prerequisites(city: Dictionary, cmd_type: String) -> Dictionary:
	var gold: int = int(city.get("gold", 0))
	# No gold cost in DEBUG_MODE
	if DebugSystem.debug_mode:
		return {"success": true}
	match cmd_type:
		"agriculture", "commerce":
			if gold < 30:
				return {"success": false, "changes": {}, "message": "Not enough gold（需要30金）"}
		"security":
			if gold < 20:
				return {"success": false, "changes": {}, "message": "Not enough gold（需要20金）"}
		"recruit":
			if gold < 50:
				return {"success": false, "changes": {}, "message": "Not enough gold（需要50金）"}
		"train":
			if gold < 10:
				return {"success": false, "changes": {}, "message": "Not enough gold（需要10金）"}
		"trade", "trade_buy":
			if int(city.get("gold", 0)) < 100:
				return {"success": false, "changes": {}, "message": "Not enough gold（需要100金买粮）"}
		"trade_sell":
			if int(city.get("food", 0)) < 500:
				return {"success": false, "changes": {}, "message": "Not enough food（需要500粮卖粮）"}
	return {"success": true}


# ── Command implementations ──

## 農業開發: 农业 + (政治×0.3 + rand(5)), 金 -30
func _cmd_agriculture(city: Dictionary) -> Dictionary:
	var politics := DEFAULT_POLITICS
	var gain := int(politics * 0.3 + RandomManager.randi_range(1, 5))
	var old_val := int(city.get("agriculture", 80))
	var new_val := clampi(old_val + gain, 0, 1000)
	city["agriculture"] = new_val
	var actual_gain := new_val - old_val
	return {"agriculture": actual_gain, "gold": -30}

## 商業開發: 商业 + (政治×0.4 + rand(5)), 金 -30
func _cmd_commerce(city: Dictionary) -> Dictionary:
	var politics := DEFAULT_POLITICS
	var gain := int(politics * 0.4 + RandomManager.randi_range(1, 5))
	var old_val := int(city.get("commerce", 80))
	var new_val := clampi(old_val + gain, 0, 1000)
	city["commerce"] = new_val
	var actual_gain := new_val - old_val
	return {"commerce": actual_gain, "gold": -30}

## Security: 治安 + (政治×0.2 + rand(3)), 金 -20
func _cmd_security(city: Dictionary) -> Dictionary:
	var politics := DEFAULT_POLITICS
	var gain := int(politics * 0.2 + RandomManager.randi_range(1, 3))
	var old_val := int(city.get("public_order", 65))
	var new_val := clampi(old_val + gain, 0, 100)
	city["public_order"] = new_val
	var actual_gain := new_val - old_val
	return {"public_order": actual_gain, "gold": -20}

## 兵士徴募: 士兵 + (人口×0.03 + rand(200)), 金 -50
func _cmd_recruit(city: Dictionary) -> Dictionary:
	var pop := int(city.get("population", 50000))
	var gain := int(pop * 0.03 + RandomManager.randi_range(1, 200))
	var old_val := int(city.get("soldiers", 5000))
	var new_val := clampi(old_val + gain, 0, 999999)
	city["soldiers"] = new_val
	var actual_gain := new_val - old_val
	return {"soldiers": actual_gain, "gold": -50}

## 兵士訓練: 训练 + (统帅×0.2 + rand(3)), 金 -10
func _cmd_train(city: Dictionary) -> Dictionary:
	var leadership := DEFAULT_LEADERSHIP
	var gain := int(leadership * 0.2 + RandomManager.randi_range(1, 3))
	var old_val := int(city.get("training", 50))
	var new_val := clampi(old_val + gain, 0, 100)
	city["training"] = new_val
	var actual_gain := new_val - old_val
	return {"training": actual_gain, "gold": -10}

## 食糧売買: 金≥100→买粮(100金→300粮), 金<100→卖粮(500粮→166金)
func _cmd_trade(trade_type: String, city: Dictionary) -> Dictionary:
	var gold := int(city.get("gold", 0))
	var food := int(city.get("food", 0))

	if trade_type == "trade_buy":
		var buy_food := 300
		city["gold"] = gold - 100
		city["food"] = mini(food + buy_food, 3000000)
		return {"food": buy_food, "gold": -100}
	elif trade_type == "trade_sell":
		var sell_food := 500
		var earn_gold := int(sell_food / 3)
		city["food"] = maxi(0, food - sell_food)
		city["gold"] = mini(gold + earn_gold, 3000000)
		return {"food": -sell_food, "gold": earn_gold}
	return {}


# ── Helpers ──

## Get remaining commands for city
# @param city_id: City ID
# @returns int: Remaining commands
func get_remaining_commands(city_id: int) -> int:
	var counts: Dictionary = GameState.get_data("city.internal_count", {})
	var used: int = counts.get(str(city_id), 0)
	return MAX_COMMANDS_PER_TURN - used


## Build change string for logging
func _changes_string(changes: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in changes:
		var val = changes[key]
		var sign := "+" if val >= 0 else ""
		parts.append("%s=%s%d" % [key, sign, val])
	return " ".join(parts)


## Build result message for UI
func _build_message(cmd_type: String, changes: Dictionary) -> String:
	var messages := {
		"agriculture": "Agriculture完成，农业+%d，消耗金30",
		"commerce": "Commerce完成，商业+%d，消耗金30",
		"security": "治安提升完成，治安+%d，消耗金20",
		"recruit": "征兵完成，士兵+%d，消耗金50",
		"train": "训练完成，训练+%d，消耗金10",
		"trade": "交易完成，粮%s%d，金%s%d",
		"trade_buy": "交易完成，粮%s%d，金%s%d",
		"trade_sell": "交易完成，粮%s%d，金%s%d",

	}
	var msg_template = messages.get(cmd_type, "指令执行完成")
	if cmd_type == "trade" or cmd_type == "trade_buy" or cmd_type == "trade_sell":
		var food_chg = changes.get("food", 0)
		var gold_chg = changes.get("gold", 0)
		var food_sign := "+" if food_chg >= 0 else ""
		var gold_sign := "+" if gold_chg >= 0 else ""
		return msg_template % [food_sign, food_chg, gold_sign, gold_chg]
	else:
		for key in changes:
			if key != "gold" and changes[key] > 0:
				return msg_template % changes[key]
	return msg_template % 0
