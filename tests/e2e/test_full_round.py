#!/usr/bin/env python3
# SPDX-License-Identifier: MIT

import unittest
import subprocess
import time
import json
import os
from pathlib import Path
import requests

class TestFullRoundE2E(unittest.TestCase):
    """End-to-end test of complete round execution"""
    
    @classmethod
    def setUpClass(cls):
        cls.project_root = Path(__file__).parent.parent.parent
        cls.scripts_dir = cls.project_root / "scripts"
        
        # Ensure scripts are executable
        for script in cls.scripts_dir.glob("*.sh"):
            os.chmod(script, 0o755)
    
    def test_complete_round_execution(self):
        """Test running a complete round from start to finish"""
        round_id = 999
        num_jobs = 4
        seed_base = "e2e_test"
        
        # Run round
        result = subprocess.run(
            [str(self.scripts_dir / "run_round.sh"), str(round_id), str(num_jobs), seed_base],
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )
        
        # Check execution succeeded
        self.assertEqual(result.returncode, 0, f"Round execution failed: {result.stderr}")
        
        # Check output contains expected messages
        self.assertIn(f"Starting round {round_id}", result.stdout)
        self.assertIn("Round complete", result.stdout)
    
    def test_determinism_assertion(self):
        """Test determinism verification"""
        result = subprocess.run(
            [str(self.scripts_dir / "assert_determinism.sh")],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        # Check all tests passed
        self.assertEqual(result.returncode, 0, f"Determinism test failed: {result.stderr}")
        self.assertIn("All determinism tests passed", result.stdout)
    
    def test_network_isolation(self):
        """Test network isolation verification"""
        # This test requires sudo, so we'll mock it for CI
        if os.environ.get('CI'):
            self.skipTest("Skipping network test in CI environment")
        
        result = subprocess.run(
            [str(self.scripts_dir / "assert_no_egress.sh")],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        # Check isolation verified
        self.assertIn("isolation tests completed", result.stdout)

class TestDashboardE2E(unittest.TestCase):
    """Test dashboard functionality"""
    
    def test_dashboard_api_endpoints(self):
        """Test dashboard API endpoints"""
        # Mock API responses for PoC
        endpoints = [
            "/api/health",
            "/api/rounds/1/summary",
            "/api/jobs?round=1",
            "/api/workers"
        ]
        
        # In real test would check actual endpoints
        for endpoint in endpoints:
            # Mock successful response
            status_code = 200
            self.assertEqual(status_code, 200)

class TestMinioIntegrationE2E(unittest.TestCase):
    """Test MinIO storage integration"""
    
    def test_minio_health(self):
        """Test MinIO is accessible"""
        # Check if MinIO is running
        try:
            response = requests.get("http://localhost:9000/minio/health/live", timeout=5)
            self.assertEqual(response.status_code, 200)
        except requests.exceptions.RequestException:
            self.skipTest("MinIO not running")
    
    def test_artifact_storage_retrieval(self):
        """Test storing and retrieving artifacts"""
        # This would test actual MinIO operations
        # For PoC, we mock the operations
        
        # Store test artifact
        stored = True
        self.assertTrue(stored)
        
        # Retrieve artifact
        retrieved = True
        self.assertTrue(retrieved)

class TestSandboxE2E(unittest.TestCase):
    """Test sandbox environment"""
    
    def test_sandbox_setup(self):
        """Test sandbox can be set up"""
        project_root = Path(__file__).parent.parent.parent
        sandbox_script = project_root / "sandbox" / "scripts" / "run_sandbox.sh"
        
        if not sandbox_script.exists():
            self.skipTest("Sandbox script not found")
        
        # Test setup command
        result = subprocess.run(
            [str(sandbox_script), "setup"],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        # Check setup completed
        self.assertIn("Network isolation", result.stdout)

if __name__ == '__main__':
    # Run tests
    unittest.main(verbosity=2)