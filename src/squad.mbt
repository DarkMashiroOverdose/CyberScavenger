// =================================================================
// 单位与队伍数据管理 (squad.mbt)
// =================================================================
let selected_squad_display_entities: Ref[Array[@system.Entity]] = Ref::new([])
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
  db.set(UnitType::PurpleTriangle, { name: "紫色三角", color_tag: SynergyTag::Purple, shape_tag: UnitShape::Triangle, hp:7,   atk:3,
    gdd: "每 1 秒对一定范围内敌人发射射线，造成 4 点伤害并附加0.5秒静止！！未完成内容！！"})
  db.set(UnitType::PurpleCircle,   { name: "紫色圆形", color_tag: SynergyTag::Purple, shape_tag: UnitShape::Circle,   hp:9,   atk:1,
    gdd: "每 15 秒为队伍施加 1 次持续 8 秒的增益，使单位技能冷却速率加快1.5倍！！未完成内容！！"})
  db.set(UnitType::GreenSquare,    { name: "绿色方块", color_tag: SynergyTag::Green,  shape_tag: UnitShape::Square,   hp:9,   atk:6,
    gdd: "每 2 秒可在身边释放一定范围的毒气，毒气有迟滞效果，每秒造成6点伤害！！未完成内容！！"})
  db.set(UnitType::GreenTriangle,  { name: "绿色三角", color_tag: SynergyTag::Green,  shape_tag: UnitShape::Triangle, hp:6,   atk:5,
    gdd: "每 5 秒投射 1 枚毒气弹，直接命中敌人造成 2 点伤害，并留下毒气区域，毒气有迟滞效果，每秒造成 3 点伤害"})
  db.set(UnitType::GreenCircle,    { name: "绿色圆形", color_tag: SynergyTag::Green,  shape_tag: UnitShape::Circle,   hp:6,   atk:1,
    gdd: "单位在场时，队列每 10 秒，为血量最低的队员恢复 1 HP！！未完成内容！！"})
  db.set(UnitType::BlueSquare,     { name: "蓝色方块", color_tag: SynergyTag::Blue,   shape_tag: UnitShape::Square,   hp:9,   atk:6,
    gdd: "每 5 秒以自身为圆心，对一定半径范围的敌人施加持续5秒的每秒 2 点伤害的持续伤害"})
  db.set(UnitType::BlueTriangle,   { name: "蓝色三角", color_tag: SynergyTag::Blue,   shape_tag: UnitShape::Triangle, hp:7,   atk:5,
    gdd: "每 3 秒发射 1 条闪电链，首次命中敌人造成 4 点伤害，随后闪电链分裂至其他敌人，共分裂两次，每次分裂伤害减半！！未完成内容！！"})
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