#!/usr/bin/env python3

import subprocess
import os
import signal

import argparse
import os
from dotenv import load_dotenv


# Load environment variables from .env file
load_dotenv()

# Set up argument parser
parser = argparse.ArgumentParser(description="Read config from CLI or .env")

# Define arguments
parser.add_argument("--kind_image", type=str, help="kind node image")
parser.add_argument("--k8s_version", type=str, help="kubernetes version")
parser.add_argument("--use_docker", type=str, help="flag to use docker when true or podman when false")

# Parse arguments
args = parser.parse_args()

# Configuration
container_name = "dev-container"
#image_name = "quay.io/powercloud/knative-prow-tests:latest"
image_name = "quay.io/p_serverless/knative-prow-tests:latest"
mount_dir = os.path.abspath("./")
kind_cluster_name = "mkpod"

# Fallback to environment variables if arguments are not provided
kind_image = args.kind_image or os.getenv("KIND_IMAGE")
k8s_version = args.k8s_version or os.getenv("K8S_VERSION")
use_docker = args.use_docker or os.getenv("USE_DOCKER", "True").lower() == "true"

#use_docker = True  # Set to False to use Podman

def run_cmd(cmd, check=True, capture_output=False):
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=capture_output, text=True)

def create_kind_cluster():
    run_cmd(["kind", "create", "cluster", "--image", f"{kind_image}:{k8s_version}", "--name", kind_cluster_name])

def delete_kind_cluster():
    run_cmd(["kind", "delete", "cluster", "--name", kind_cluster_name])

def start_container():
    runtime = "docker" if use_docker else "podman"
    run_cmd([
        runtime, "run", "-it", "--rm",
        "--name", container_name,
        "--volume", f"{mount_dir}:/mnt/shared",
        "--network", "host",  # Allows access to Kind cluster
        image_name,
        "/bin/bash"
    ])

def main():
    try:
        os.makedirs(mount_dir, exist_ok=True)
        print("Creating Kind cluster...")
        create_kind_cluster()

        print("Starting container with shell access...")
        start_container()

    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
    finally:
        print("Cleaning up...")
        delete_kind_cluster()

if __name__ == "__main__":
    main()
