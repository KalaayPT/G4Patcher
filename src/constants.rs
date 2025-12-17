#![warn(clippy::nursery, clippy::pedantic)]

/// The synthOverlay for Pokémon Platinum.
pub const GAME_DEPENDENT_OVERLAY_PLAT: &str = "0065";

/// The synthOverlay for Pokémon HeartGold/SoulSilver.
pub const GAME_DEPENDENT_OVERLAY_HG: &str = "0000";

/// The header bytes for Pokémon Platinum.
pub const PLATINUM_BYTES: [u8; 4] = [0x43, 0x50, 0x55, 0x45]; // "CPUE" in bytes
/// The header bytes for Pokémon HeartGold.
pub const HEARTGOLD_BYTES: [u8; 4] = [0x49, 0x50, 0x4B, 0x45]; // "IPKE" in bytes

/// The header bytes for Pokémon SoulSilver.
pub const SOULSILVER_BYTES: [u8; 4] = [0x49, 0x50, 0x47, 0x45]; // "IPGE" in bytes

pub const PLATINUM: &str = "Platinum";
pub const HEARTGOLD: &str = "HeartGold";
pub const SOULSILVER: &str = "SoulSilver";

pub const PREASSEMBLE_DIRECTIVE: &str = "PREASSEMBLE";
pub const PATCH_DIRECTIVE: &str = "PATCH";
