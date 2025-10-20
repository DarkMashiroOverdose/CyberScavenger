pub enum UpgradeEffect {
  AddBaseDamageFlat(Double)
  MultiplyBaseDamage(Double)
  MultiplyAttackCooldown(Double)
  AddMaxHPFlat(Double)           // 注意: MaxHP 需要特殊处理
  AddCritRateFlat(Double)
  MultiplyBaseEffectDuration(Double) 
  MultiplySpeedFlat(Double)
  MultiplySpeedPercent(Double)
  // ... 其他类型 ...
} derive(Show, Eq)