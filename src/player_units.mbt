/// 单位的协同标签（颜色）
pub enum SynergyTag {
  Orange // 安全型
  Purple // 故障型
  Green  // 侵蚀型
  Blue   // 离散型
} derive(Eq, Show, Hash)

/// 单位的攻击类型（形状）
pub enum UnitShape {
  Square   // 方形
  Triangle // 三角形
  Circle   // 圆形
} derive(Eq, Show, Hash)

// 我们可以创建一个新的组件来存储这些信息
pub let synergy_tags: Map[@system.Entity, SynergyTag] = Map::new()
pub let unit_shapes: Map[@system.Entity, UnitShape] = Map::new()

pub enum PlayerUnitType {
  OrangeSquare
  OrangeTriangle
  OrangeCircle
}

let gdd_color_palette: Map[SynergyTag, String] = Map::from_array([
  (SynergyTag::Orange, "#f1ae89ff"),
  (SynergyTag::Purple, "#DDA0DD"),
  (SynergyTag::Green,  "#90EE90"),
  (SynergyTag::Blue,   "#6495ED"),
])
///生成一个单位的基本流水线
fn spawn_base_player_unit(pos: @math.Vec2D, shape_tag: UnitShape, color_tag: SynergyTag) -> @system.Entity {
  let new_unit = @system.Entity::new()

  @position.positions.set(new_unit, pos)
  teams.set(new_unit, Team::Player)
  synergy_tags.set(new_unit, color_tag)
  unit_shapes.set(new_unit, shape_tag)

  let (base_shape, offset, radius) = match shape_tag {
    UnitShape::Square =>   (@sprite.Shape::rect(35.0, 35.0, 10.0), @math.Vec2D(-17.5, -17.5), 0.0)
    UnitShape::Triangle => (@sprite.Shape::triangle(38.0, 0.0), @math.Vec2D::zero(), 18.0)
    UnitShape::Circle =>   (@sprite.Shape::circle(15.0), @math.Vec2D::zero(), 0.0)
  }
  
  sizes.set(new_unit, { radius: radius })

  let color_str = gdd_color_palette.get(color_tag).unwrap_or("#FFFFFF")
  let colored_shape = @sprite.ColoredShape::new(base_shape, @sprite.DrawStyle::fill(color_str))
  let z_index = 100 
  let sprite = @sprite.Sprite::from_shape(colored_shape, z_index, offset=offset)
  @sprite.sprites.set(new_unit, sprite)

  return new_unit
}

fn add_new_orange_square(pos: @math.Vec2D) -> @system.Entity {

  let new_unit = spawn_base_player_unit(pos, UnitShape::Square, SynergyTag::Orange)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 10.0, max: 10.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  combat_stats.set(new_unit, {
    attack_range: 40.0, 
    attack_type: AttackType::AoE, 
    aoe_radius: 40.0,
    on_hit_effects: [OnHitEffect::DealDamage(10.0,None)], 
    attack_cooldown: 5.0, 
    
    current_cooldown: 0.0, 
    aggro_range: 40.0, 
    crit_rate: 0.0,
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
  })

  all_units.val.push(new_unit)

  return new_unit
}

/// 创建橙色三角形单位
fn add_new_orange_triangle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Triangle, SynergyTag::Orange)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 6.0, max: 6.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD: 每1秒发射子弹, 4点直伤, 2点溅射(半径100)
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::DealDamage(4.0, Some(VFX_Type::BulletImpact)), 

        OnHitEffect::AreaOfEffect(
          [OnHitEffect::DealDamage(2.0, None)],
          100.0, 
          None,
        )
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_orange_circle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Circle, SynergyTag::Orange)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 10.0, max: 10.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD: 每5秒在地图上生成一个可拾取的抵挡2次伤害的次数盾
  // 现在还没做次数盾系统，就先和三角形一个模板占位 TODO
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::DealDamage(3.0, Some(VFX_Type::BulletImpact)), 

        OnHitEffect::AreaOfEffect(
          [OnHitEffect::DealDamage(1.0, None)],
          100.0, 
          None,
        )
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}
fn add_new_purple_square(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Square, SynergyTag::Purple)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 9.0, max: 9.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD: HP 8, 每5秒以自身为圆心，对半径5范围内发射60度扇形范围伤害。
  // 现在还没做扇形范围伤害系统，就先和三角形一个模板占位 TODO
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::DealDamage(3.0, Some(VFX_Type::BulletImpact)), 

        OnHitEffect::AreaOfEffect(
          [OnHitEffect::DealDamage(1.0, None)],
          100.0, 
          None,
        )
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_purple_triangle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Triangle, SynergyTag::Purple)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 7.0, max: 7.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD: 每3秒对3个敌人发射激光射线，造成4点伤害并附加0.5秒静止效果
  // 现在还没做对多个敌人同时造成单体伤害系统，就先和三角形一个模板占位 TODO
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::DealDamage(3.0, Some(VFX_Type::BulletImpact)), 

        OnHitEffect::AreaOfEffect(
          [OnHitEffect::DealDamage(1.0, None)],
          100.0, 
          None,
        )
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_purple_circle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Circle, SynergyTag::Purple)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 9, max: 9, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD: HP 9, 每15秒为队列添加1次持续8秒的buff，使成员技能冷却（CD）计数加快1.5倍。
  // 现在还没做对队施加增益的系统，就先和三角形一个模板占位 TODO
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::DealDamage(3.0, Some(VFX_Type::BulletImpact)), 

        OnHitEffect::AreaOfEffect(
          [OnHitEffect::DealDamage(1.0, None)],
          100.0, 
          None,
        )
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_green_square(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Square, SynergyTag::Green)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 9.0, max: 9.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD: HP 8, 持续以自身为中心，在半径8范围内释放毒气，每1秒造成1点伤害。
  // 现在还没做无目标释放攻击的功能，就先随便做一个近战释放毒气的系统
  combat_stats.set(new_unit, {
    attack_range: 100.0, 
    attack_type: AttackType::Melee,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::CreateHazardousArea(
          [OnHitEffect::DealDamage(6.0, Some(SpeedLow)),ApplyBuff(BuffType::MultiplySpeed(0.5), 3.0, Some(SpeedLow))], 
          100.0,
          5.0,
          Some(PoisonCloud)
        ),
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 100.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_green_triangle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Triangle, SynergyTag::Green)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 6, max: 6, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD:  每6秒投射1枚毒气弹，直接命中敌人造成2点伤害，并留下半径4的毒气区域（每1秒1伤害）
  // 现在还没做对多个敌人同时造成单体伤害系统，就先和三角形一个模板占位 TODO
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::DealDamage(2.0, None), // 直接伤害
        OnHitEffect::CreateHazardousArea(
          [OnHitEffect::DealDamage(3.0, Some(SpeedLow)),ApplyBuff(BuffType::MultiplySpeed(0.5), 3.0, Some(SpeedLow))], 
          100.0,
          5.0,
          Some(PoisonCloud)
        ),
    ],
    attack_cooldown: 5.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_green_circle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Circle, SynergyTag::Green)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 6, max: 6, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD: HP 5, 在场时，队列每造成5点总伤害，为血量最低的队员恢复1HP
  // 现在还没做对队回血的系统，就先和三角形一个模板占位 TODO
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::DealDamage(3.0, Some(VFX_Type::BulletImpact)), 

        OnHitEffect::AreaOfEffect(
          [OnHitEffect::DealDamage(1.0, None)],
          100.0, 
          None,
        )
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_blue_square(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Square, SynergyTag::Blue)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 10.0, max: 10.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD: 每 5 秒以自身为圆心，对一定半径范围的敌人施加持续5秒的每秒 2 点伤害的持续伤害
  // 现在还没做对具体半径群攻的系统，就先用aoe模版 TODO
  combat_stats.set(new_unit, {
    attack_range: 60.0, 
    attack_type: AttackType::AoE, 
    aoe_radius: 40.0,
    on_hit_effects: [OnHitEffect::DealDamage(2.0,None)], 
    attack_cooldown: 0.5, 
    
    current_cooldown: 0.0, 
    aggro_range: 40.0, 
    crit_rate: 0.0,
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_blue_triangle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Triangle, SynergyTag::Blue)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 7, max: 7, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD: 每3秒发射1条闪电链，首次命中敌人造成4点伤害，分裂至其他敌人（每条分裂伤害减半），每条分裂2条。
  // 现在还没做闪电链条系统，就先和三角形一个模板占位 TODO
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::DealDamage(3.0, Some(VFX_Type::BulletImpact)), 

        OnHitEffect::AreaOfEffect(
          [OnHitEffect::DealDamage(1.0, None)],
          100.0, 
          None,
        )
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_blue_circle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Circle, SynergyTag::Blue)

  let (bar_bg, bar_fg) = attach_health_bar()
  healths.set(new_unit, { current: 6, max: 6, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg })

  // GDD: HP 9, 每8秒为队列附加1次持续4秒的buff，使所有成员造成的每次伤害额外增加1点。
  // 现在还没做对队施加增益的系统，就先和三角形一个模板占位 TODO
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::DealDamage(3.0, Some(VFX_Type::BulletImpact)), 

        OnHitEffect::AreaOfEffect(
          [OnHitEffect::DealDamage(1.0, None)],
          100.0, 
          None,
        )
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: None, 
  })

  all_units.val.push(new_unit)
  return new_unit
}