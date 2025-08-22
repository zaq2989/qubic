// SPDX-License-Identifier: MIT
use rand::{RngCore, SeedableRng};
use rand_chacha::ChaCha8Rng;
use sha2::{Digest, Sha256};

/// Deterministic random number generator based on seed
pub struct DeterministicRng {
    inner: ChaCha8Rng,
}

impl DeterministicRng {
    /// Create a new deterministic RNG from a seed
    pub fn from_seed(seed: &[u8]) -> Self {
        // Convert arbitrary seed to 32 bytes using SHA256
        let mut hasher = Sha256::new();
        hasher.update(seed);
        let hash = hasher.finalize();
        
        let mut seed_bytes = [0u8; 32];
        seed_bytes.copy_from_slice(&hash);
        
        Self {
            inner: ChaCha8Rng::from_seed(seed_bytes),
        }
    }
    
    /// Get the next u32 value
    pub fn next_u32(&mut self) -> u32 {
        self.inner.next_u32()
    }
    
    /// Get the next u64 value
    pub fn next_u64(&mut self) -> u64 {
        self.inner.next_u64()
    }
    
    /// Fill a buffer with random bytes
    pub fn fill_bytes(&mut self, dest: &mut [u8]) {
        self.inner.fill_bytes(dest)
    }
    
    /// Generate a random value in range [0, max)
    pub fn gen_range(&mut self, max: u32) -> u32 {
        if max == 0 {
            return 0;
        }
        self.next_u32() % max
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_deterministic_output() {
        let seed = b"test_seed_12345";
        
        // Create two RNGs with the same seed
        let mut rng1 = DeterministicRng::from_seed(seed);
        let mut rng2 = DeterministicRng::from_seed(seed);
        
        // They should produce the same sequence
        for _ in 0..100 {
            assert_eq!(rng1.next_u32(), rng2.next_u32());
        }
    }
    
    #[test]
    fn test_different_seeds() {
        let seed1 = b"seed1";
        let seed2 = b"seed2";
        
        let mut rng1 = DeterministicRng::from_seed(seed1);
        let mut rng2 = DeterministicRng::from_seed(seed2);
        
        // Different seeds should produce different sequences
        let mut same_count = 0;
        for _ in 0..100 {
            if rng1.next_u32() == rng2.next_u32() {
                same_count += 1;
            }
        }
        
        // Should be very unlikely to have many matches
        assert!(same_count < 10);
    }
}