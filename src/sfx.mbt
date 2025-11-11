///用于存储背景音乐句柄的全局变量 ---
let bgm_audio_object: Ref[Option[@canvas.Audio]] = Ref::new(None)
///踪音频是否已被用户交互解锁
let audio_unlocked: Ref[Bool] = Ref::new(false)

let sfx_enabled: Ref[Bool] = Ref::new(true)    // 音效开关
let bgm_enabled: Ref[Bool] = Ref::new(true)    // BGM 开关
let sfx_volume: Ref[Double] = Ref::new(0.8)    // 音效音量 (0.0 到 1.0)
let bgm_volume: Ref[Double] = Ref::new(0.1)    // BGM 音量 (0.0 到 1.0)

/// 定义所有音效的类型
pub enum SFX_Type {
  PlayerShoot
  EnemyShoot
  EnemyHit
  Explosion
  UITick
  Dead
  Select
  PowerUp
} derive(Eq, Show, Hash)

/// 定义一个音效的静态属性
pub struct SFX_Template {
  audio_object: @canvas.Audio // 存储预加载的音频对象
}

/// 全局的音效库，存储所有音效模板
pub let sfx_library: Map[SFX_Type, SFX_Template] = Map::new()

pub fn setup_sfx_library() -> Unit {
  println("【音频】: 正在预加载所有 SFX...")

  // --- PlayerShoot 和 EnemyShoot (共享同一个音频对象) ---
  let shoot_audio = @canvas.Audio::new("assets/sfx/Shoot.wav") // 预加载
  shoot_audio.set_volume(1.0 * sfx_volume.val) // 设置音量
  shoot_audio.set_loop(false) // 确保不循环
  sfx_library.set(SFX_Type::PlayerShoot, { audio_object: shoot_audio })
  sfx_library.set(SFX_Type::EnemyShoot, { audio_object: shoot_audio }) // 复用

  // --- EnemyHit ---
  let hit_audio = @canvas.Audio::new("assets/sfx/Hit.wav")
  hit_audio.set_volume(0.8 * sfx_volume.val)
  hit_audio.set_loop(false)
  sfx_library.set(SFX_Type::EnemyHit, { audio_object: hit_audio })

  // --- Select ---
  let select_audio = @canvas.Audio::new("assets/sfx/Blip.wav")
  select_audio.set_volume(0.8 * sfx_volume.val)
  select_audio.set_loop(false)
  sfx_library.set(SFX_Type::Select, { audio_object: select_audio })

  // --- Dead ---
  let dead_audio = @canvas.Audio::new("assets/sfx/Dead.wav")
  dead_audio.set_volume(0.8 * sfx_volume.val)
  dead_audio.set_loop(false)
  sfx_library.set(SFX_Type::Dead, { audio_object: dead_audio })

  // --- PowerUp ---
  let powerup_audio = @canvas.Audio::new("assets/sfx/PowerUp.wav")
  powerup_audio.set_volume(0.8 * sfx_volume.val)
  powerup_audio.set_loop(false)
  sfx_library.set(SFX_Type::PowerUp, { audio_object: powerup_audio })

  println("【音频】: SFX 预加载完成。")
}


pub struct SFX_Request {
  sfx_type: SFX_Type
  position: Option[@math.Vec2D] // 为未来的空间音效预留
}

/// 全局的音效请求队列
pub let sfx_requests: Ref[Array[SFX_Request]] = Ref::new([])

/// 统一处理所有音效播放请求的系统
pub fn audio_spawner_system(backend: &@system.Backend) -> Unit {
  guard audio_unlocked.val && sfx_enabled.val else {
      if sfx_requests.val.length() > 0 { sfx_requests.val.clear() } // 清空请求
      return
  }

  let played_this_frame: Set[SFX_Type] = Set::new()

  for request in sfx_requests.val {
    if !played_this_frame.contains(request.sfx_type) {
      if sfx_library.get(request.sfx_type) is Some(template) {
        
        template.audio_object.play() 
        
        played_this_frame.add(request.sfx_type)
      }
    }
  }

  if sfx_requests.val.length() > 0 {
    sfx_requests.val.clear()
  }
}

pub fn update_all_sfx_volume() -> Unit {
  
  if sfx_library.get(SFX_Type::EnemyHit) is Some(template) {
      template.audio_object.set_volume(0.8 * sfx_volume.val)
  }
  if sfx_library.get(SFX_Type::PlayerShoot) is Some(template) {
      template.audio_object.set_volume(1.0 * sfx_volume.val)
  }
  if sfx_library.get(SFX_Type::EnemyHit) is Some(template) {
      template.audio_object.set_volume(1.0 * sfx_volume.val)
  }
  if sfx_library.get(SFX_Type::Select) is Some(template) {
      template.audio_object.set_volume(0.8 * sfx_volume.val)
  }
  if sfx_library.get(SFX_Type::Dead) is Some(template) {
      template.audio_object.set_volume(0.8 * sfx_volume.val)
  }
  if sfx_library.get(SFX_Type::PowerUp) is Some(template) {
      template.audio_object.set_volume(0.8 * sfx_volume.val)
  }
  
  println("【音频】: SFX 音量已更新为 \{sfx_volume.val}")
}

/// 更新 BGM 音量
pub fn update_bgm_volume() -> Unit {
  // 操作 bgm_audio_object
  if bgm_audio_object.val is Some(audio_obj) {
    // 只有在 BGM 启用时才设置音量，否则保持为 0
    let new_volume = if bgm_enabled.val { bgm_volume.val } else { 0.0 }
    audio_obj.set_volume(new_volume)
    println("【音频】: BGM 音量已更新为 \{new_volume}")
  }
}

/// 切换 BGM 播放状态
pub fn toggle_bgm() -> Unit {
  bgm_enabled.val = !bgm_enabled.val // 切换状态

  if bgm_enabled.val {
    println("【音频】: BGM 已开启")
    match bgm_audio_object.val {
      Some(audio_obj) => {
        // 对象已存在，恢复音量并继续播放
        audio_obj.set_volume(bgm_volume.val)
        if audio_obj.is_paused() {
          audio_obj.play()
        }
      }
      None => {
        println("【音频】: BGM 对象不存在，正在创建...")
        let new_bgm = @canvas.Audio::new("assets/sfx/inst.mp3")
        new_bgm.set_volume(bgm_volume.val)
        new_bgm.set_loop(true)
        new_bgm.play()
        bgm_audio_object.val = Some(new_bgm)
      }
    }
  } else {
    // --- 关闭 BGM ---
    println("【音频】: BGM 已关闭")
    if bgm_audio_object.val is Some(audio_obj) {
      audio_obj.pause()
      audio_obj.set_volume(0.0) 
    }
  }
}