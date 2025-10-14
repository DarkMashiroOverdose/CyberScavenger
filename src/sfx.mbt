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
  path: String            // 音频文件路径
  default_volume: Double  // 默认音量
  // 未来可以扩展，比如随机音高范围等
}

/// 全局的音效库，存储所有音效模板
pub let sfx_library: Map[SFX_Type, SFX_Template] = Map::new()

pub fn setup_sfx_library() -> Unit {
  sfx_library.set(SFX_Type::PlayerShoot, {
    path: "assets/sfx/Shoot.wav",
    default_volume: 1.0,
  })

  sfx_library.set(SFX_Type::EnemyShoot, {
    path: "assets/sfx/Shoot.wav",
    default_volume: 1.0,
  })

  sfx_library.set(SFX_Type::EnemyHit, {
    path: "assets/sfx/Hit.wav",
    default_volume: 0.8,
  })

  sfx_library.set(SFX_Type::Select, {
    path: "assets/sfx/Blip.wav",
    default_volume: 0.8,
  })

  sfx_library.set(SFX_Type::Dead, {
    path: "assets/sfx/Dead.wav",
    default_volume: 0.8,
  })
  sfx_library.set(SFX_Type::PowerUp, {
    path: "assets/sfx/PowerUp.wav",
    default_volume: 0.8,
  })
  // ... 在这里注册所有其他的音效 ...
}


pub struct SFX_Request {
  sfx_type: SFX_Type
  position: Option[@math.Vec2D] // 为未来的空间音效预留
}

/// 全局的音效请求队列
pub let sfx_requests: Ref[Array[SFX_Request]] = Ref::new([])

/// 统一处理所有音效播放请求的系统
pub fn audio_spawner_system(backend: &@system.Backend) -> Unit {
  // 遍历本帧所有的音效请求
  for request in sfx_requests.val {
    if sfx_library.get(request.sfx_type) is Some(template) {
      
      // 在这里可以加入更复杂的逻辑，比如根据距离计算音量等
      let final_volume = template.default_volume

      // 播放音效
      let _ = @audio.play_audio(
        backend,
        template.path,
        volume=final_volume,
        loop_=false,
      )
    }
  }

  // 清空本帧的请求队列，为下一帧做准备
  if sfx_requests.val.length() > 0 {
    sfx_requests.val.clear()
  }
}