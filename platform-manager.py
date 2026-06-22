#!/usr/bin/env python3
"""
Data Platform Setup and Management Script
Provides utilities for managing the data platform
"""

import json
import requests
import time
import subprocess
import sys
from typing import Optional, Dict, Any

class DataPlatformManager:
    """Manage data platform services"""

    def __init__(self, kafka_connect_url: str = "http://localhost:8083"):
        self.kafka_connect_url = kafka_connect_url

    def create_connector(self, connector_config: Dict[str, Any]) -> bool:
        """Create a Kafka Connect connector"""
        try:
            url = f"{self.kafka_connect_url}/connectors"
            headers = {"Content-Type": "application/json"}

            response = requests.post(url, json=connector_config, headers=headers, timeout=10)

            if response.status_code in [200, 201]:
                print(f"✓ Connector created: {connector_config.get('name')}")
                return True
            else:
                print(f"✗ Failed to create connector: {response.text}")
                return False
        except Exception as e:
            print(f"✗ Error: {e}")
            return False

    def delete_connector(self, connector_name: str) -> bool:
        """Delete a Kafka Connect connector"""
        try:
            url = f"{self.kafka_connect_url}/connectors/{connector_name}"
            response = requests.delete(url, timeout=10)

            if response.status_code in [200, 204]:
                print(f"✓ Connector deleted: {connector_name}")
                return True
            else:
                print(f"✗ Failed to delete connector: {response.text}")
                return False
        except Exception as e:
            print(f"✗ Error: {e}")
            return False

    def get_connector_status(self, connector_name: str) -> Optional[Dict]:
        """Get status of a Kafka Connect connector"""
        try:
            url = f"{self.kafka_connect_url}/connectors/{connector_name}/status"
            response = requests.get(url, timeout=10)

            if response.status_code == 200:
                return response.json()
            else:
                print(f"✗ Connector not found: {connector_name}")
                return None
        except Exception as e:
            print(f"✗ Error: {e}")
            return None

    def list_connectors(self) -> list:
        """List all Kafka Connect connectors"""
        try:
            url = f"{self.kafka_connect_url}/connectors"
            response = requests.get(url, timeout=10)

            if response.status_code == 200:
                connectors = response.json()
                print(f"✓ Found {len(connectors)} connector(s):")
                for connector in connectors:
                    print(f"  - {connector}")
                return connectors
            else:
                print("✗ Failed to list connectors")
                return []
        except Exception as e:
            print(f"✗ Error: {e}")
            return []

    def wait_for_service(self, url: str, timeout: int = 60) -> bool:
        """Wait for a service to be ready"""
        start_time = time.time()

        while time.time() - start_time < timeout:
            try:
                response = requests.get(url, timeout=5)
                if response.status_code < 500:
                    print(f"✓ Service ready: {url}")
                    return True
            except:
                pass

            print(".", end="", flush=True)
            time.sleep(1)

        print(f"\n✗ Timeout waiting for {url}")
        return False

def load_connector_config(file_path: str) -> Optional[Dict]:
    """Load connector configuration from JSON file"""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"✗ File not found: {file_path}")
        return None
    except json.JSONDecodeError:
        print(f"✗ Invalid JSON: {file_path}")
        return None

def main():
    """Main function"""
    import argparse

    parser = argparse.ArgumentParser(description="Data Platform Manager")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Create connector command
    create_parser = subparsers.add_parser("create", help="Create a Kafka Connect connector")
    create_parser.add_argument("config", help="Path to connector configuration JSON file")

    # Delete connector command
    delete_parser = subparsers.add_parser("delete", help="Delete a Kafka Connect connector")
    delete_parser.add_argument("name", help="Connector name")

    # Status command
    status_parser = subparsers.add_parser("status", help="Get connector status")
    status_parser.add_argument("name", help="Connector name")

    # List command
    subparsers.add_parser("list", help="List all connectors")

    # Wait command
    wait_parser = subparsers.add_parser("wait", help="Wait for a service")
    wait_parser.add_argument("url", help="Service URL")
    wait_parser.add_argument("--timeout", type=int, default=60, help="Timeout in seconds")

    args = parser.parse_args()
    manager = DataPlatformManager()

    if args.command == "create":
        config = load_connector_config(args.config)
        if config:
            manager.create_connector(config)

    elif args.command == "delete":
        manager.delete_connector(args.name)

    elif args.command == "status":
        status = manager.get_connector_status(args.name)
        if status:
            print(json.dumps(status, indent=2))

    elif args.command == "list":
        manager.list_connectors()

    elif args.command == "wait":
        manager.wait_for_service(args.url, args.timeout)

    else:
        parser.print_help()

if __name__ == "__main__":
    main()

