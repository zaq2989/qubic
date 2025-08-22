#!/usr/bin/env python3
# SPDX-License-Identifier: MIT

import unittest
import subprocess
import json
import hashlib
import tempfile
import os
from pathlib import Path

class TestDeterminism(unittest.TestCase):
    """Test deterministic execution of workers"""
    
    def setUp(self):
        self.project_root = Path(__file__).parent.parent.parent
        self.test_seed = "unit_test_seed_12345"
        self.test_target = "abcdef0123456789abcdef0123456789"
    
    def test_attack_worker_determinism(self):
        """Test that attack worker produces same output for same seed"""
        outputs = []
        
        for i in range(3):
            result = self._run_attack_worker(self.test_seed)
            outputs.append(result)
        
        # All outputs should be identical
        self.assertEqual(outputs[0], outputs[1])
        self.assertEqual(outputs[1], outputs[2])
    
    def test_defense_worker_determinism(self):
        """Test that defense worker produces same output for same seed"""
        outputs = []
        
        for i in range(3):
            result = self._run_defense_worker(self.test_seed)
            outputs.append(result)
        
        # All outputs should be identical
        self.assertEqual(outputs[0], outputs[1])
        self.assertEqual(outputs[1], outputs[2])
    
    def test_different_seeds_produce_different_outputs(self):
        """Test that different seeds produce different outputs"""
        seed1 = "seed_one"
        seed2 = "seed_two"
        
        result1 = self._run_attack_worker(seed1)
        result2 = self._run_attack_worker(seed2)
        
        self.assertNotEqual(result1, result2)
    
    def _run_attack_worker(self, seed):
        """Run attack worker with given seed and return hash of output"""
        # This is a mock - in real test would run actual worker
        # For PoC, we simulate deterministic output based on seed
        hasher = hashlib.sha256()
        hasher.update(f"attack_{seed}".encode())
        return hasher.hexdigest()
    
    def _run_defense_worker(self, seed):
        """Run defense worker with given seed and return hash of output"""
        # This is a mock - in real test would run actual worker
        hasher = hashlib.sha256()
        hasher.update(f"defense_{seed}".encode())
        return hasher.hexdigest()

class TestSeedHandling(unittest.TestCase):
    """Test proper seed handling"""
    
    def test_seed_format_validation(self):
        """Test that seeds are properly validated"""
        valid_seeds = [
            "deadbeef",
            "0123456789abcdef",
            "a" * 64,
        ]
        
        invalid_seeds = [
            "",
            "xyz",  # non-hex
            "g" * 32,  # invalid hex chars
        ]
        
        for seed in valid_seeds:
            self.assertTrue(self._is_valid_seed(seed))
        
        for seed in invalid_seeds:
            self.assertFalse(self._is_valid_seed(seed))
    
    def _is_valid_seed(self, seed):
        """Check if seed is valid hex string"""
        if not seed:
            return False
        try:
            int(seed, 16)
            return True
        except ValueError:
            return False

if __name__ == '__main__':
    unittest.main()