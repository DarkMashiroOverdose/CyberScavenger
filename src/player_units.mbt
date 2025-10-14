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
    UnitShape::Square =>   (@sprite.Shape::rect(35.0, 35.0, 10.0), @math.Vec2D(-17.5, -17.5), 20.0)
    UnitShape::Triangle => (@sprite.Shape::triangle(38.0, 0.0), @math.Vec2D::zero(), 18.0)
    UnitShape::Circle =>   (@sprite.Shape::circle(15.0), @math.Vec2D::zero(), 15.0)
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

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 10.0, max: 10.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame  })

  combat_stats.set(new_unit, {
    attack_range: 120.0, 
    attack_type: AttackType::AoE, 
    aoe_radius: 150.0,
    on_hit_effects: [OnHitEffect::DealDamage(10.0,None),OnHitEffect::Knockback(15)], 
    attack_cooldown: 2.0, 
    
    current_cooldown: 0.0, 
    aggro_range: 150.0, 
    crit_rate: 0.0,
    attack_cast_vfx: Some(AoEMeeleOrange),    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: None,
  })

  all_units.val.push(new_unit)

  return new_unit
}

/// 创建橙色三角形单位
fn add_new_orange_triangle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Triangle, SynergyTag::Orange)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 6.0, max: 6.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame  })

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
        ),
        OnHitEffect::Knockback(15)
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: Some(gdd_color_palette.get(Orange).unwrap_or("#FFFFFF"))
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_orange_circle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Circle, SynergyTag::Orange)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 10.0, max: 10.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame  })

  // GDD: 每5秒在地图上生成一个可拾取的抵挡2次伤害的次数盾
  combat_stats.set(new_unit, {
    attack_range: 0.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 0.0,
    on_hit_effects: [
    ],
    attack_cooldown: 999.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: Some(gdd_color_palette.get(Orange).unwrap_or("#FFFFFF"))
  })
  team_abilities.set(new_unit, {
    effects: [
      OnHitEffect::SpawnPickup(
        PickupType::ChargeShield,       // 生成次数盾
        PickupData::ShieldData(2)       // 这个盾包含2次抵挡次数
      )
    ],
    cooldown: 5.0, 
    current_cooldown: 10.0,
    targeting_rule: TargetingRule::Self_,
    cast_vfx: None, 
    cast_sfx: None,
  })
  all_units.val.push(new_unit)
  return new_unit
}
fn add_new_purple_square(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Square, SynergyTag::Purple)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 9.0, max: 9.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame  })

  // GDD: HP 8, 每 2 秒以自身为圆心，对一定半径范围的敌人内造成 6 点伤害，在推开敌人的同时附加迟滞效果
  combat_stats.set(new_unit, {
    attack_range: 130.0, 
    attack_type: AttackType::AoE,
    aoe_radius: 180.0,
    on_hit_effects: [OnHitEffect::DealDamage(4.0,None),OnHitEffect::Knockback(100),OnHitEffect::ApplyBuff(BuffType::MultiplySpeed(0.2), 3.0, Some(SpeedLow))],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: Some(AoEMeelePurple),   
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: Some(gdd_color_palette.get(Purple).unwrap_or("#FFFFFF"))
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_purple_triangle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Triangle, SynergyTag::Purple)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 7.0, max: 7.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame })

  // GDD: 每3秒对3个敌人发射激光射线，造成4点伤害并附加1.0秒静止效果
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Ranged,
    aoe_radius: 0.0,
    on_hit_effects: [
      OnHitEffect::DealDamage(4.0, Some(VFX_Type::ForkBeamBoom),), 
      OnHitEffect::ApplyBuff(BuffType::MultiplySpeed(0.01), 1.0, Some(SpeedLow)),
      OnHitEffect::Fork(
        [OnHitEffect::DealDamage(4.0, Some(VFX_Type::ForkBeamBoom)),ApplyBuff(BuffType::MultiplySpeed(0.01), 1.0, Some(SpeedLow))],
        2,
        350.0,
        Some(VFX_Type::ForkBeam) 
      )
    ],
    attack_cooldown: 3.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: Some(ForkBeam),    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: Some(gdd_color_palette.get(Purple).unwrap_or("#FFFFFF"))
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_purple_circle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Circle, SynergyTag::Purple)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 7, max: 7, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame })

  // GDD: HP 9, 每15秒为队列添加1次持续8秒的buff，使成员技能冷却（CD）计数加快1.5倍。
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::AreaOfEffect(
          [OnHitEffect::DealDamage(1.0, None)],
          100.0, 
          None,
        ),
        OnHitEffect::Knockback(15)
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: Some(gdd_color_palette.get(Purple).unwrap_or("#FFFFFF"))
  })

  team_abilities.set(new_unit, {
    effects: [
      OnHitEffect::ApplyBuff(
        BuffType::MultiplyCooldown(1.0 / 1.25),
        8.0,
        Some(CooldownUp),
      )
    ],
    cooldown: 15.0,
    current_cooldown: 15.0,
    targeting_rule: TargetingRule::AllAllies,
    cast_vfx: None,
    cast_sfx: None,
  })

  ///让减少冷却的buff无法作用于冷却辅助单位
  cooldown_ability_units.set(new_unit, CooldownAbilityUnit::{})

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_green_square(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Square, SynergyTag::Green)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 9.0, max: 9.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame })

  // GDD: HP 8, 持续以自身为中心，在半径8范围内释放毒气，每1秒造成1点伤害。
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
        OnHitEffect::Knockback(15)
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 100.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: Some(gdd_color_palette.get(Green).unwrap_or("#FFFFFF"))
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_green_triangle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Triangle, SynergyTag::Green)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 6, max: 6, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame })

  // GDD:  每6秒投射1枚毒气弹，直接命中敌人造成2点伤害，并留下半径4的毒气区域（每1秒1伤害）
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
        OnHitEffect::Knockback(15)
    ],
    attack_cooldown: 5.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: Some(gdd_color_palette.get(Green).unwrap_or("#FFFFFF"))
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_green_circle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Circle, SynergyTag::Green)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 6, max: 6, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame })

  // GDD: HP 5, 在场时，队列每造成5点总伤害，为血量最低的队员恢复1HP
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Bullet,
    aoe_radius: 4.0,
    on_hit_effects: [
        OnHitEffect::DealDamage(1.0, Some(VFX_Type::BulletImpact)), 

        OnHitEffect::AreaOfEffect(
          [OnHitEffect::DealDamage(1.0, None)],
          100.0, 
          None,
        ),
        OnHitEffect::Knockback(15)
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: Some(gdd_color_palette.get(Green).unwrap_or("#FFFFFF"))
  })

  team_abilities.set(new_unit, {
    effects: [OnHitEffect::Heal(1.0, Some(Healing))], // 效果是治疗1点HP
    cooldown: 5.0, // 每5秒触发一次
    current_cooldown: 0, // 初始冷却
    targeting_rule: TargetingRule::LowestHealthAlly, // 目标规则是血量最低的队友
    cast_vfx: None, // 可以在这里加上施法特效
    cast_sfx: None,
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_blue_square(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Square, SynergyTag::Blue)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 10.0, max: 10.0, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame })

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
    attack_sfx: Some(PlayerShoot), 
    bullet_color: Some(gdd_color_palette.get(Blue).unwrap_or("#FFFFFF"))
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_blue_triangle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Triangle, SynergyTag::Blue)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 7, max: 7, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame })

  // GDD: 每3秒发射1条闪电链，首次命中敌人造成4点伤害，分裂至其他敌人（每条分裂伤害减半），每条分裂2条。
  combat_stats.set(new_unit, {
    attack_range: 300.0, 
    attack_type: AttackType::Ranged,
    aoe_radius: 0,
    on_hit_effects: [
        OnHitEffect::DealDamage(4.0, Some(VFX_Type::PrimaryBeamBoom)), 
        OnHitEffect::Chain(
          [OnHitEffect::DealDamage(1.0, Some(VFX_Type::ChainBeamBoom))],
          4,
          200.0,
          0.5,
          Some(VFX_Type::ChainBeam)
        ),
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: Some(PrimaryBeam),    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: None,
  })

  all_units.val.push(new_unit)
  return new_unit
}

fn add_new_blue_circle(pos: @math.Vec2D) -> @system.Entity {
  
  let new_unit = spawn_base_player_unit(pos, UnitShape::Circle, SynergyTag::Blue)

  let (bar_bg, bar_fg, shield_frame) = attach_health_bar()
  healths.set(new_unit, { current: 6, max: 6, bar_bg_entity: bar_bg, bar_fg_entity: bar_fg, shield_frame_entity: shield_frame })

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
        ),
        OnHitEffect::Knockback(15)
    ],
    attack_cooldown: 1.0,
    
    current_cooldown: 0.0,
    aggro_range: 350.0, 
    crit_rate: 0.05, 
    attack_cast_vfx: None,    
    area_effect_vfx: None,
    attack_sfx: Some(PlayerShoot), 
    bullet_color: Some(gdd_color_palette.get(Blue).unwrap_or("#FFFFFF"))
  })

  all_units.val.push(new_unit)
  return new_unit
}