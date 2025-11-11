///用于存储背景音乐句柄的全局变量 ---
let bgm_handle: Ref[Option[@system.AudioHandle]] = Ref::new(None)
///踪音频是否已被用户交互解锁
let audio_unlocked: Ref[Bool] = Ref::new(false)

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

// 【修改】函数签名不再需要 backend
pub fn setup_sfx_library() -> Unit {
  println("【音频】: 正在预加载所有 SFX...")

  // --- PlayerShoot 和 EnemyShoot (共享同一个音频对象) ---
  let shoot_audio = @canvas.Audio::new("assets/sfx/Shoot.wav") // 预加载
  shoot_audio.set_volume(1.0) // 设置音量
  shoot_audio.set_loop(false) // 确保不循环
  sfx_library.set(SFX_Type::PlayerShoot, { audio_object: shoot_audio })
  sfx_library.set(SFX_Type::EnemyShoot, { audio_object: shoot_audio }) // 复用

  // --- EnemyHit ---
  let hit_audio = @canvas.Audio::new("assets/sfx/Hit.wav")
  hit_audio.set_volume(0.8)
  hit_audio.set_loop(false)
  sfx_library.set(SFX_Type::EnemyHit, { audio_object: hit_audio })

  // --- Select ---
  let select_audio = @canvas.Audio::new("assets/sfx/Blip.wav")
  select_audio.set_volume(0.8)
  select_audio.set_loop(false)
  sfx_library.set(SFX_Type::Select, { audio_object: select_audio })

  // --- Dead ---
  let dead_audio = @canvas.Audio::new("assets/sfx/Dead.wav")
  dead_audio.set_volume(0.8)
  dead_audio.set_loop(false)
  sfx_library.set(SFX_Type::Dead, { audio_object: dead_audio })

  // --- PowerUp ---
  let powerup_audio = @canvas.Audio::new("assets/sfx/PowerUp.wav")
  powerup_audio.set_volume(0.8)
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
pub fn audio_spawner_system(backend: &@system.Backend) -> Unit { // 保持 backend 签名
  // 【新增】检查音频是否已解锁
  guard audio_unlocked.val else {
      if sfx_requests.val.length() > 0 { sfx_requests.val.clear() } // 清空请求
      return
  }

  // 记录本帧已经播放过的音效类型 (不变)
  let played_this_frame: Set[SFX_Type] = Set::new()

  for request in sfx_requests.val {
    if !played_this_frame.contains(request.sfx_type) {
      // 【修改】从库中获取预加载的 Audio 对象
      if sfx_library.get(request.sfx_type) is Some(template) {
        
        // 【修改】调用对象自己的 play 方法，这是一个轻量级操作
        template.audio_object.play()
        
        played_this_frame.add(request.sfx_type)
      }
    }
  }

  // 清空本帧的请求队列 (不变)
  if sfx_requests.val.length() > 0 {
    sfx_requests.val.clear()
  }
}