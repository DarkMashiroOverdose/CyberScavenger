// =================================================================
// 单位与队伍数据管理 (squad.mbt)
// =================================================================
struct SquadSlot {
  portrait_entity: @system.Entity
  delete_button_entity: @system.Entity
}
let squad_display_slots: Ref[Array[SquadSlot]] = Ref::new([])
pub enum UnitType {
  OrangeSquare
  OrangeTriangle
  OrangeCircle
  PurpleSquare
  PurpleTriangle
  PurpleCircle
  GreenSquare
  GreenTriangle
  GreenCircle
  BlueSquare
  BlueTriangle
  BlueCircle
} derive(Eq, Show, Hash)

pub struct UnitDefinition {
  name: String
  color_tag: SynergyTag
  shape_tag: UnitShape
  hp: Int
  atk: Int
  gdd: String
}

// 修正 #2: 将变量名改为小写的 snake_case
pub let unit_definitions: Map[UnitType, UnitDefinition] = {
  let db = Map::new()
  db.set(UnitType::OrangeSquare,   { name: "橙色方块", color_tag: SynergyTag::Orange, shape_tag: UnitShape::Square,   hp:10,  atk:5,
    gdd: "每 5 秒以自身为圆心，对一定半径范围的敌人内造成 10 点伤害"})
  db.set(UnitType::OrangeTriangle, { name: "橙色三角", color_tag: SynergyTag::Orange, shape_tag: UnitShape::Triangle, hp:6,   atk:4,
    gdd: "每 1 秒发射 1 颗子弹攻击敌人， 造成 4 点直接伤害+半径2的溅射伤害"})
  db.set(UnitType::OrangeCircle,   { name: "橙色圆形", color_tag: SynergyTag::Orange, shape_tag: UnitShape::Circle,   hp:10,  atk:1,
    gdd: "每 5 秒在地图上生成一个可拾取的抵挡 2 次伤害的次数盾\n！！未完成内容！！"})
  db.set(UnitType::PurpleSquare,   { name: "紫色方块", color_tag: SynergyTag::Purple, shape_tag: UnitShape::Square,   hp:9,   atk:6,
    gdd: "每 5 秒以自身为圆心，对一定距离内一个60度扇形范围内的敌人造成8伤害\n！！未完成内容！！"})
  db.set(UnitType::PurpleTriangle, { name: "紫色三角", color_tag: SynergyTag::Purple, shape_tag: UnitShape::Triangle, hp:7,   atk:4,
    gdd: "每 1 秒对一定范围内 3 个敌人发射射线，造成 4 点伤害并附加1秒静止效果"})
  db.set(UnitType::PurpleCircle,   { name: "紫色圆形", color_tag: SynergyTag::Purple, shape_tag: UnitShape::Circle,   hp:7,   atk:1,
    gdd: "每 15 秒为队伍施加 1 次持续 8 秒的增益，使单位技能冷却速率加快1.25倍\n注意：此类单位无法享受技能冷却加成"})
  db.set(UnitType::GreenSquare,    { name: "绿色方块", color_tag: SynergyTag::Green,  shape_tag: UnitShape::Square,   hp:9,   atk:6,
    gdd: "每 2 秒可在身边释放一定范围的毒气，毒气有迟滞效果，每秒造成6点伤害"})
  db.set(UnitType::GreenTriangle,  { name: "绿色三角", color_tag: SynergyTag::Green,  shape_tag: UnitShape::Triangle, hp:6,   atk:5,
    gdd: "每 5 秒投射 1 枚毒气弹，直接命中敌人造成 2 点伤害，并留下毒气区域，毒气有迟滞效果，每秒造成 3 点伤害"})
  db.set(UnitType::GreenCircle,    { name: "绿色圆形", color_tag: SynergyTag::Green,  shape_tag: UnitShape::Circle,   hp:6,   atk:1,
    gdd: "单位在场时，队列每 5 秒，为血量最低的队员恢复 1 HP"})
  db.set(UnitType::BlueSquare,     { name: "蓝色方块", color_tag: SynergyTag::Blue,   shape_tag: UnitShape::Square,   hp:9,   atk:6,
    gdd: "每 5 秒以自身为圆心，对一定半径范围的敌人施加持续5秒的每秒 2 点伤害的持续伤害"})
  db.set(UnitType::BlueTriangle,   { name: "蓝色三角", color_tag: SynergyTag::Blue,   shape_tag: UnitShape::Triangle, hp:7,   atk:5,
    gdd: "每 3 秒发射 1 条闪电链，首次命中敌人造成 4 点伤害，随后闪电链分裂至其他敌人，共分裂两次，每次分裂伤害减半"})
  db.set(UnitType::BlueCircle,     { name: "蓝色圆形", color_tag: SynergyTag::Blue,   shape_tag: UnitShape::Circle,   hp:6,   atk:1,
    gdd: "每 8 秒队伍施加 1 次持续 4 秒的增益，使所有成员造成的每次伤害额外增加2点增伤！！未完成内容！！"})
  db
}

pub let selected_squad: Ref[Array[UnitType]] = Ref::new([])

pub fn spawn_player_unit_by_type(unit_type: UnitType, pos: @math.Vec2D) -> Unit {
    let _ = match unit_type {
        UnitType::OrangeSquare => add_new_orange_square(pos)
        UnitType::OrangeTriangle => add_new_orange_triangle(pos)
        UnitType::OrangeCircle => add_new_orange_circle(pos)
        UnitType::PurpleSquare => add_new_purple_square(pos)
        UnitType::PurpleTriangle => add_new_purple_triangle(pos)
        UnitType::PurpleCircle => add_new_purple_circle(pos)
        UnitType::GreenSquare => add_new_green_square(pos)
        UnitType::GreenTriangle => add_new_green_triangle(pos)
        UnitType::GreenCircle => add_new_green_circle(pos)
        UnitType::BlueSquare => add_new_blue_square(pos)
        UnitType::BlueTriangle => add_new_blue_triangle(pos)
        UnitType::BlueCircle => add_new_blue_circle(pos)
    }
}

pub struct SynergyTier {
  count: Int      // 激活所需的单位数量
  bonus_value: Double // 对应的奖励数值 (例如 1.2, 1.4, 1.6)
  bonus_text: String  // 对应的奖励描述 (例如 "20%")
}

// 新增 #2: 定义一个结构体来存储一种颜色的完整协同信息
pub struct SynergyInfo {
  name: String
  description: String
  tiers: Array[SynergyTier]
  state: String
}

// 新增 #3: 创建一个全局的、完整的“协同数据库”
pub let synergy_database: Map[SynergyTag, SynergyInfo] = {
  let db = Map::new()
  
  db.set(SynergyTag::Orange, {
    name: "安全型数字生命",
    description: "每3个可增加HP上限",
    tiers: [
      { count: 0, bonus_value: 1.0, bonus_text: "0%" },
      { count: 3, bonus_value: 1.2, bonus_text: "20%" },
      { count: 6, bonus_value: 1.4, bonus_text: "40%" },
      { count: 9, bonus_value: 1.6, bonus_text: "60%" },
    ],
    state: "全队HP上限增加"
  })

  db.set(SynergyTag::Purple, {
    name: "故障型数字生命",
    description: "每3个增加队伍暴击",
    tiers: [
      { count: 0, bonus_value: 1.0, bonus_text: "0%" },
      { count: 3, bonus_value: 0.1, bonus_text: "10%" },
      { count: 6, bonus_value: 0.2, bonus_text: "20%" },
      { count: 9, bonus_value: 0.3, bonus_text: "30%" },
    ],
    state: "全队暴击率增加"
  })

  db.set(SynergyTag::Green, {
    name: "侵蚀型数字生命",
    description: "每3个可增加攻击力",
    tiers: [
      { count: 0, bonus_value: 0, bonus_text: "0点" },
      { count: 3, bonus_value: 2, bonus_text: "2点" },
      { count: 6, bonus_value: 4, bonus_text: "4点" },
      { count: 9, bonus_value: 6, bonus_text: "6点" },
    ],
    state: "全队攻击力增加"
  })

  db.set(SynergyTag::Blue, {
    name: "离散型数字生命",
    description: "每3个增加队伍闪避",
    tiers: [
      { count: 0, bonus_value: 0.1, bonus_text: "0%" },
      { count: 3, bonus_value: 0.1, bonus_text: "10%" },
      { count: 6, bonus_value: 0.2, bonus_text: "20%" },
      { count: 9, bonus_value: 0.3, bonus_text: "30%" },
    ],
    state: "全队闪避率增加"
  })
  db
}