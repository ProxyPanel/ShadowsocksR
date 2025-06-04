# -*- coding: utf-8 -*-
import time

class SpeedTester:
    """
    Simple token-bucket rate limiter based on speed_limit_per_user (KB/s).
    Call wait(n) before sending n bytes to enforce the speed limit.
    """
    def __init__(self, speed_limit_kbps):
        # Convert KB/s to bytes/s
        self.speed_limit = speed_limit_kbps * 1024
        self.tokens = self.speed_limit
        self.last_time = time.time()

    def wait(self, data_len):
        """
        data_len: number of bytes about to be sent
        """
        now = time.time()
        elapsed = now - self.last_time
        self.last_time = now

        # Refill tokens
        self.tokens += elapsed * self.speed_limit
        if self.tokens > self.speed_limit:
            self.tokens = self.speed_limit

        # If not enough tokens, sleep
        if self.tokens < data_len:
            wait_time = (data_len - self.tokens) / float(self.speed_limit)
            time.sleep(wait_time)
            self.tokens = 0
        else:
            self.tokens -= data_len
