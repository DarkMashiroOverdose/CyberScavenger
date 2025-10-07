/// 定义技能的目标规则
pub enum TargetingRule {
  Self_             // 仅对自己生效
  AllAllies         // 对所有友方单位生效
  LowestHealthAlly  // 对血量百分比最低的友方单位生效
}

/// 定义团队技能组件
pub struct TeamAbility {
  effects: Array[OnHitEffect]     // 要施加的效果列表
  cooldown: Double                // 技能触发的冷却时间
  mut current_cooldown: Double    // 当前剩余冷却
  targeting_rule: TargetingRule   // 目标规则
  cast_vfx: Option[VFX_Type]      // 视觉特效
  cast_sfx: Option[SFX_Type]      // 音效
}

/// 存储所有拥有团队技能的单位
pub let team_abilities: Map[@system.Entity, TeamAbility] = Map::new()

pub fn team_ability_system(_backend: &@system.Backend) -> Unit {
  let delta_seconds = 1.0 / 60.0

  for unit, ability in team_abilities {
    let mut current_cooldown_multiplier = 1.0
    if active_buffs.get(unit) is Some(buff_list) {
      for buff in buff_list {
        if buff.buff_type is MultiplyCooldown(factor) {
          current_cooldown_multiplier *= factor
        }
      }
    }
    
    if ability.current_cooldown > 0.0 {
      // 冷却倒数的速率会根据Buff加快
      ability.current_cooldown -= delta_seconds / current_cooldown_multiplier
      continue
    }

    ability.current_cooldown = ability.cooldown

    let targets: Array[@system.Entity] = []
    match ability.targeting_rule {
      TargetingRule::Self_ => {
        targets.push(unit)
      }
      TargetingRule::AllAllies => {
        for ally in all_units.val {
          if teams.get(ally) == Some(Team::Player) { // 假设技能只由玩家单位拥有
            targets.push(ally)
          }
        }
      }
       TargetingRule::LowestHealthAlly => {
        let mut lowest_health_ally: Option[@system.Entity] = None
        let mut min_health_percentage: Double = 1.0 
        for ally in all_units.val {
          if teams.get(ally) == Some(Team::Player) {
            if healths.get(ally) is Some(health) {
              if health.max > 0.0 {
                let current_percentage = health.current / health.max
                
                if current_percentage < min_health_percentage {
                  min_health_percentage = current_percentage
                  lowest_health_ally = Some(ally)
                }
              }
            }
          }
        }
        if lowest_health_ally is Some(target_ally) {
          targets.push(target_ally)
        }
      }
    }

    if targets.length() > 0 {
      ability.current_cooldown = ability.cooldown

      if ability.cast_sfx is Some(sfx) {
        sfx_requests.val.push({ sfx_type: sfx, position: None })
      }
      if ability.cast_vfx is Some(vfx) {
         if @position.positions.get(unit) is Some(pos) {
           vfx_requests.val.push({ vfx_type: vfx, position: pos.0, rotation: 0.0, parent_entity: Some(unit) })
         }
      }
      
      for target in targets {
        apply_all_effects(unit, target, ability.effects)
      }
    }
  }
}