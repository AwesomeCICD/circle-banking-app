# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Flaky tests for userservice to demonstrate various flakiness patterns
"""

import random
import time
import hashlib
import threading
import unittest
from unittest.mock import patch, mock_open
from concurrent.futures import ThreadPoolExecutor

from sqlalchemy.exc import SQLAlchemyError
import jwt

from userservice.userservice import create_app
from userservice.tests.constants import (
    TIMESTAMP_FORMAT,
    EXAMPLE_USER_REQUEST,
    EXAMPLE_USER,
    EXPECTED_FIELDS,
    EXAMPLE_PRIVATE_KEY,
    EXAMPLE_PUBLIC_KEY,
)


class TestFlakyUserservice(unittest.TestCase):
    """
    Flaky test cases for userservice
    """

    def setUp(self):
        """Setup Flask TestClient and mock userdatabase"""
        with patch('userservice.userservice.open', mock_open(read_data='foo')):
            with patch(
                'os.environ',
                {
                    'VERSION': '1',
                    'TOKEN_EXPIRY_SECONDS': '1',
                    'PRIV_KEY_PATH': '1',
                    'PUB_KEY_PATH': '1',
                    'ENABLE_TRACING': 'false',
                },
            ):
                with patch('userservice.userservice.UserDb') as mock_db:
                    self.mocked_db = mock_db
                    self.flask_app = create_app()
                    self.flask_app.config['TESTING'] = True
                    self.test_app = self.flask_app.test_client()

    def test_concurrent_user_creation_race_condition(self):
        """Test that exposes race conditions in concurrent user creation"""
        created_users = []
        errors = []
        
        def create_user_worker(user_suffix):
            try:
                # Mock return value for each thread
                self.mocked_db.return_value.get_user.return_value = None
                self.mocked_db.return_value.generate_accountid.return_value = f'123{user_suffix}'
                
                user_request = EXAMPLE_USER_REQUEST.copy()
                user_request['username'] = f'testuser{user_suffix}'
                
                # Add random delay to increase chance of race condition
                time.sleep(random.uniform(0.001, 0.01))
                
                response = self.test_app.post('/users', data=user_request)
                created_users.append((user_suffix, response.status_code))
                
                # Simulate checking if user was actually created
                if response.status_code == 201:
                    time.sleep(random.uniform(0.001, 0.005))
                    # Race condition: another thread might have created same user
                    if len([u for u in created_users if u[1] == 201]) > 10 and random.random() < 0.35:
                        raise AssertionError("Too many users created concurrently")
            except Exception as e:
                errors.append(str(e))
        
        # Run multiple threads
        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(create_user_worker, i) for i in range(15)]
            for future in futures:
                future.result()
        
        if errors:
            self.fail(f"Race condition detected: {errors[0]}")

    def test_jwt_token_timing_attack(self):
        """Test that simulates timing-based JWT validation flakiness"""
        example_user = EXAMPLE_USER.copy()
        self.mocked_db.return_value.get_user.return_value = example_user
        self.flask_app.config['PRIVATE_KEY'] = EXAMPLE_PRIVATE_KEY
        
        # Generate JWT token
        example_user_request = EXAMPLE_USER_REQUEST.copy()
        
        with patch('bcrypt.checkpw', return_value=True):
            response = self.test_app.get('/login', query_string=example_user_request)
            token = response.json.get('token')
        
        # Simulate variable token validation time
        validation_times = []
        for _ in range(10):
            start = time.time()
            try:
                jwt.decode(algorithms='RS256', jwt=token, key=EXAMPLE_PUBLIC_KEY)
                validation_times.append(time.time() - start)
            except:
                pass
            time.sleep(random.uniform(0.001, 0.005))
        
        # This will be flaky based on system performance (35% failure rate)
        avg_time = sum(validation_times) / len(validation_times) if validation_times else 0
        if avg_time > 0.01 and random.random() < 0.35:  # 10ms threshold and random 35% failure
            self.fail(f"JWT validation too slow: {avg_time:.4f}s")

    def test_password_hash_collision_probability(self):
        """Test that occasionally fails due to hash collision simulation"""
        # Simulate password hashing with different salts
        password = "testpassword123"
        hashes = set()
        
        for _ in range(random.randint(50, 200)):
            # Simulate bcrypt with different salts
            salt = random.randint(1000000, 9999999)
            hash_input = f"{password}{salt}".encode()
            hash_result = hashlib.md5(hash_input).hexdigest()[:8]  # Truncated for higher collision chance
            hashes.add(hash_result)
        
        # Artificially high collision rate for testing (35% failure rate)
        unique_hashes = len(hashes)
        if unique_hashes < 50 and random.random() < 0.35:  # Fail with 35% chance
            self.fail(f"Too many hash collisions detected: {unique_hashes} unique hashes")

    def test_database_connection_pool_exhaustion(self):
        """Test that simulates database connection pool issues"""
        connections = []
        
        # Simulate multiple database operations
        for i in range(random.randint(20, 100)):
            try:
                # Mock database operations
                self.mocked_db.return_value.get_user.return_value = None
                
                # Simulate connection being held
                connection_id = f"conn_{i}"
                connections.append(connection_id)
                
                # Random delay simulating query time
                time.sleep(random.uniform(0.001, 0.01))
                
                # Simulate pool exhaustion (moderate failure rate)
                if len(connections) > 50 and random.random() < 0.35:
                    raise SQLAlchemyError("Connection pool exhausted")
                    
            except SQLAlchemyError as e:
                self.fail(f"Database connection issue: {str(e)}")
            finally:
                # Randomly "forget" to close connections
                if random.random() > 0.1:  # 10% chance of connection leak
                    connections.pop() if connections else None

    def test_user_login_with_system_clock_drift(self):
        """Test sensitive to system clock changes"""
        import datetime

        # Get current time with some random offset
        current_time = time.time()
        clock_drift = random.uniform(-5, 5)  # +/- 5 seconds
        adjusted_time = current_time + clock_drift

        # Mock time-sensitive operations
        with patch('time.time', return_value=adjusted_time):
            example_user = EXAMPLE_USER.copy()
            self.mocked_db.return_value.get_user.return_value = example_user
            self.flask_app.config['PRIVATE_KEY'] = EXAMPLE_PRIVATE_KEY

            with patch('bcrypt.checkpw', return_value=True):
                response = self.test_app.get('/login', query_string=EXAMPLE_USER_REQUEST)

                # Time-sensitive assertion that might fail with clock drift
                # Introduce randomness - fail 35% of the time when drift is large
                if abs(clock_drift) > 3 and random.random() < 0.35:
                    self.fail(f"Clock drift too large for secure login: {clock_drift:.2f}s")
                
                self.assertEqual(response.status_code, 200)

    def test_memory_leak_simulation(self):
        """Test that might fail under memory pressure"""
        memory_hogs = []
        
        try:
            # Create memory pressure
            for i in range(random.randint(100, 1000)):
                # Simulate memory leak in user session data
                session_data = {
                    'user_id': f'user_{i}',
                    'session_data': 'x' * random.randint(1000, 10000),
                    'history': [f'action_{j}' for j in range(100)]
                }
                memory_hogs.append(session_data)
            
            # Test user creation under memory pressure
            self.mocked_db.return_value.get_user.return_value = None
            self.mocked_db.return_value.generate_accountid.return_value = '123'
            
            response = self.test_app.post('/users', data=EXAMPLE_USER_REQUEST)
            self.assertEqual(response.status_code, 201)
            
        except MemoryError:
            self.fail("Memory pressure caused user creation to fail")
        finally:
            del memory_hogs

    def test_thread_local_storage_interference(self):
        """Test with thread-local storage conflicts"""
        thread_results = {}
        
        def worker(thread_id):
            # Each thread tries to set thread-local data
            import threading
            local_data = threading.local()
            local_data.user_context = f"user_context_{thread_id}"
            
            time.sleep(random.uniform(0.01, 0.05))
            
            # Race condition with thread-local data
            if hasattr(local_data, 'user_context'):
                expected_context = f"user_context_{thread_id}"
                actual_context = local_data.user_context
                
                if expected_context != actual_context:
                    thread_results[thread_id] = f"Context mismatch: expected {expected_context}, got {actual_context}"
                else:
                    thread_results[thread_id] = "success"
            else:
                thread_results[thread_id] = "no context found"
        
        # Run multiple threads
        threads = []
        for i in range(10):
            thread = threading.Thread(target=worker, args=(i,))
            threads.append(thread)
            thread.start()
        
        for thread in threads:
            thread.join()
        
        # Check for any failures
        failures = [result for result in thread_results.values() if result != "success"]
        if failures:
            self.fail(f"Thread interference detected: {failures[0]}")

    def test_network_packet_loss_simulation(self):
        """Test that simulates network reliability issues"""
        packet_loss_rate = random.uniform(0.05, 0.20)  # 5-20% packet loss
        successful_requests = 0
        total_requests = 20
        
        for attempt in range(total_requests):
            # Simulate packet loss
            if random.random() < packet_loss_rate:
                continue  # Packet lost, skip this attempt
            
            try:
                # Simulate network delay variation
                time.sleep(random.uniform(0.001, 0.02))
                
                self.mocked_db.return_value.get_user.return_value = None
                response = self.test_app.get('/ready')
                
                if response.status_code == 200:
                    successful_requests += 1
                    
            except Exception:
                continue  # Network error
        
        success_rate = successful_requests / total_requests
        if success_rate < 0.8:  # Require 80% success rate
            self.fail(f"Network reliability too low: {success_rate:.2%} success rate")

    def test_unicode_encoding_edge_cases(self):
        """Test that fails on certain Unicode edge cases"""
        problematic_usernames = [
            "user\u0000null",  # Null byte
            "user\ufeffbom",   # BOM character
            "user\u202eRTL",   # Right-to-left override
            "user\U0001f4a9",  # Emoji
            "user\u0301combining",  # Combining character
        ]
        
        username = random.choice(problematic_usernames)
        
        try:
            self.mocked_db.return_value.get_user.return_value = None
            self.mocked_db.return_value.generate_accountid.return_value = '123'
            
            user_request = EXAMPLE_USER_REQUEST.copy()
            user_request['username'] = username
            
            response = self.test_app.post('/users', data=user_request)
            
            # Some Unicode characters might cause unexpected behavior
            if username.encode('utf-8', errors='ignore').decode('utf-8') != username:
                self.fail(f"Unicode encoding issue with username: {repr(username)}")
                
        except UnicodeError as e:
            self.fail(f"Unicode handling failed: {e}")

    def test_leap_second_time_handling(self):
        """Test that might fail during leap second events"""
        # Simulate time around a leap second
        base_time = 1483228799  # Dec 31, 2016 23:59:59 UTC (leap second year)
        leap_second_offset = random.uniform(-2, 2)
        
        mock_time = base_time + leap_second_offset
        
        with patch('time.time', return_value=mock_time):
            try:
                # Operations that depend on precise timing
                start = time.time()
                time.sleep(0.001)  # Small sleep
                elapsed = time.time() - start
                
                # During leap second, timing might be off
                if elapsed < 0 or elapsed > 0.1:  # Negative time or too long
                    self.fail(f"Time anomaly detected: {elapsed:.6f}s elapsed")
                
                # Test normal user operation
                response = self.test_app.get('/ready')
                self.assertEqual(response.status_code, 200)
                
            except Exception as e:
                if "leap" in str(e).lower():
                    self.fail(f"Leap second handling issue: {e}")
                raise