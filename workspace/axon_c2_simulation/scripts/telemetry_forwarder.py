#!/usr/bin/env python3
"""
MAVLink Telemetry Forwarder with System ID Filtering
Forwards telemetry from PX4 to separate ports, filtering by system ID

Architecture:
- PX4 broadcasts on 14540, 14541, 14542 (bidirectional)
- Forwarder receives from each port and filters by system ID
- Only forwards messages matching the expected system ID to corresponding output port
- Parser reads from 14550-14552 (clean, filtered data per drone)
"""

import socket
import threading
import time
import logging
from typing import Dict
from pymavlink import mavutil

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class SystemIdTelemetryForwarder:
    """Forwards MAVLink telemetry filtering by system ID"""
    
    def __init__(self, px4_port: int, broadcast_port: int, expected_sysid: int, drone_id: int):
        self.px4_port = px4_port
        self.broadcast_port = broadcast_port
        self.expected_sysid = expected_sysid
        self.drone_id = drone_id
        self.running = False
        self.thread = None
        
        # MAVLink connection for parsing
        self.mav_conn = None
        
        # Statistics
        self.packets_received = 0
        self.packets_forwarded = 0
        self.packets_filtered = 0
        self.bytes_forwarded = 0
        self.start_time = None
        self.system_ids_seen = set()
        
    def start(self):
        """Start the forwarder thread"""
        if self.running:
            return
            
        self.running = True
        self.start_time = time.time()
        self.thread = threading.Thread(target=self._forward_loop, daemon=True)
        self.thread.start()
        logger.info(
            f"Drone {self.drone_id}: Forwarder started "
            f"(PX4:{self.px4_port} -> Broadcast:{self.broadcast_port}, "
            f"filtering sysid={self.expected_sysid})"
        )
    
    def stop(self):
        """Stop the forwarder"""
        self.running = False
        if self.thread:
            self.thread.join(timeout=2)
        logger.info(f"Drone {self.drone_id}: Forwarder stopped")
    
    def _forward_loop(self):
        """Main forwarding loop with system ID filtering"""
        # Create MAVLink connection to parse messages
        conn_str = f'udp:127.0.0.1:{self.px4_port}'
        self.mav_conn = mavutil.mavlink_connection(conn_str, source_system=255)
        
        # Create socket to broadcast filtered telemetry
        send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        
        logger.info(f"Drone {self.drone_id}: Listening on 127.0.0.1:{self.px4_port}")
        logger.info(f"Drone {self.drone_id}: Broadcasting to 127.0.0.1:{self.broadcast_port}")
        logger.info(f"Drone {self.drone_id}: Filtering for system ID {self.expected_sysid}")
        
        consecutive_timeouts = 0
        last_stats_time = time.time()
        
        while self.running:
            try:
                # Receive MAVLink message with timeout
                msg = self.mav_conn.recv_match(blocking=True, timeout=1.0)
                
                if msg is None:
                    consecutive_timeouts += 1
                    if consecutive_timeouts >= 10:
                        logger.warning(
                            f"Drone {self.drone_id}: No data for {consecutive_timeouts} seconds"
                        )
                        consecutive_timeouts = 0
                    continue
                
                # Reset timeout counter
                consecutive_timeouts = 0
                self.packets_received += 1
                
                # Get the system ID from the message
                msg_sysid = msg.get_srcSystem()
                self.system_ids_seen.add(msg_sysid)
                
                # Filter: only forward messages from our expected system ID
                if msg_sysid == self.expected_sysid:
                    # Get the raw bytes of the message
                    msg_bytes = msg.get_msgbuf()
                    
                    # Forward to broadcast port
                    send_sock.sendto(msg_bytes, ('127.0.0.1', self.broadcast_port))
                    
                    # Update statistics
                    self.packets_forwarded += 1
                    self.bytes_forwarded += len(msg_bytes)
                else:
                    # This message is from a different system ID - filter it out
                    self.packets_filtered += 1
                
                # Log stats periodically
                current_time = time.time()
                if current_time - last_stats_time >= 10.0:
                    self._log_stats()
                    last_stats_time = current_time
                
            except Exception as e:
                logger.error(f"Drone {self.drone_id}: Forward error: {e}")
                time.sleep(0.1)
        
        send_sock.close()
    
    def _log_stats(self):
        """Log periodic statistics"""
        duration = time.time() - self.start_time if self.start_time else 0
        if duration > 0:
            forward_rate = self.packets_forwarded / duration
            filter_pct = (self.packets_filtered / self.packets_received * 100) if self.packets_received > 0 else 0
            
            logger.info(
                f"Drone {self.drone_id}: "
                f"Fwd={self.packets_forwarded} ({forward_rate:.1f} Hz), "
                f"Filtered={self.packets_filtered} ({filter_pct:.1f}%), "
                f"SysIDs seen={sorted(self.system_ids_seen)}"
            )
    
    def get_stats(self) -> Dict:
        """Get forwarder statistics"""
        duration = time.time() - self.start_time if self.start_time else 0
        return {
            'drone_id': self.drone_id,
            'expected_sysid': self.expected_sysid,
            'packets_received': self.packets_received,
            'packets_forwarded': self.packets_forwarded,
            'packets_filtered': self.packets_filtered,
            'filter_percentage': (self.packets_filtered / self.packets_received * 100) if self.packets_received > 0 else 0,
            'bytes_forwarded': self.bytes_forwarded,
            'forward_rate_hz': self.packets_forwarded / duration if duration > 0 else 0,
            'bandwidth_kbps': (self.bytes_forwarded * 8 / 1024) / duration if duration > 0 else 0,
            'system_ids_seen': sorted(self.system_ids_seen)
        }


class MultiDroneForwarder:
    """Manages telemetry forwarding for multiple drones with system ID filtering"""
    
    def __init__(self, config: list):
        """
        config: list of dicts with keys: drone_id, px4_port, broadcast_port, expected_sysid
        """
        self.forwarders = []
        
        for cfg in config:
            forwarder = SystemIdTelemetryForwarder(
                px4_port=cfg['px4_port'],
                broadcast_port=cfg['broadcast_port'],
                expected_sysid=cfg['expected_sysid'],
                drone_id=cfg['drone_id']
            )
            self.forwarders.append(forwarder)
    
    def start_all(self):
        """Start all forwarders"""
        logger.info("Starting all telemetry forwarders with system ID filtering...")
        for forwarder in self.forwarders:
            forwarder.start()
            time.sleep(1)  # Stagger startup
        logger.info(f"Started {len(self.forwarders)} forwarders")
    
    def stop_all(self):
        """Stop all forwarders"""
        logger.info("Stopping all forwarders...")
        for forwarder in self.forwarders:
            forwarder.stop()
        logger.info("All forwarders stopped")
    
    def print_stats(self):
        """Print statistics for all forwarders"""
        print("\n" + "="*80)
        print("  MAVLink Telemetry Forwarder Statistics (with System ID Filtering)")
        print("="*80)
        
        for forwarder in self.forwarders:
            stats = forwarder.get_stats()
            print(f"\nDrone {stats['drone_id']} (Expected SysID: {stats['expected_sysid']}):")
            print(f"  Received:       {stats['packets_received']:,} packets")
            print(f"  Forwarded:      {stats['packets_forwarded']:,} packets @ {stats['forward_rate_hz']:.1f} Hz")
            print(f"  Filtered:       {stats['packets_filtered']:,} packets ({stats['filter_percentage']:.1f}%)")
            print(f"  Data forwarded: {stats['bytes_forwarded']/1024:.1f} KB")
            print(f"  Bandwidth:      {stats['bandwidth_kbps']:.1f} kbps")
            print(f"  SysIDs seen:    {stats['system_ids_seen']}")
        
        print("="*80 + "\n")


def main():
    """Run the telemetry forwarder for 3 drones with system ID filtering"""
    
    config = [
        {
            'drone_id': 1,
            'px4_port': 14540,
            'broadcast_port': 14550,
            'expected_sysid': 1  # Only forward messages from system ID 1
        },
        {
            'drone_id': 2,
            'px4_port': 14541,
            'broadcast_port': 14551,
            'expected_sysid': 2  # Only forward messages from system ID 2
        },
        {
            'drone_id': 3,
            'px4_port': 14542,
            'broadcast_port': 14552,
            'expected_sysid': 3  # Only forward messages from system ID 3
        },
    ]
    
    forwarder_manager = MultiDroneForwarder(config)
    
    print("="*80)
    print("  MAVLink Telemetry Forwarder with System ID Filtering")
    print("="*80)
    print("\nForwarding telemetry (filtering by system ID):")
    for cfg in config:
        print(f"  Drone {cfg['drone_id']} (SysID {cfg['expected_sysid']}): "
              f"PX4 port {cfg['px4_port']} -> Broadcast port {cfg['broadcast_port']}")
    print("\nThis ensures each parser receives ONLY messages from its assigned drone.")
    print("Press Ctrl+C to stop")
    print("="*80 + "\n")
    
    try:
        forwarder_manager.start_all()
        
        # Print stats every 10 seconds
        while True:
            time.sleep(10)
            forwarder_manager.print_stats()
            
    except KeyboardInterrupt:
        print("\n\nStopping forwarders...")
        forwarder_manager.stop_all()
        forwarder_manager.print_stats()
        print("Done.")


if __name__ == "__main__":
    main()