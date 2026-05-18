#![warn(clippy::nursery, clippy::pedantic)]

/// The synthOverlay for Pokémon Platinum.
pub const GAME_DEPENDENT_OVERLAY_PLAT: &str = "0009";

/// The synthOverlay for Pokémon HeartGold/SoulSilver.
pub const GAME_DEPENDENT_OVERLAY_HG: &str = "0000";

/// The game code for Pokémon Platinum.
pub const PLATINUM_CODE: &str = "CPUE";
/// The game code for Pokémon HeartGold.
pub const HEARTGOLD_CODE: &str = "IPKE";

/// The game code for Pokémon SoulSilver.
pub const SOULSILVER_CODE: &str = "IPGE";

pub const PLATINUM: &str = "Platinum";
pub const HEARTGOLD: &str = "HeartGold";
pub const SOULSILVER: &str = "SoulSilver";

pub const PREASSEMBLE_DIRECTIVE: &str = "PREASSEMBLE";
pub const PATCH_DIRECTIVE: &str = "PATCH";
