import sys
import subprocess
import datetime

import boto3

from config import (
    BUTLER_PATH,
    GODOT_PATH,
    ITCH_USER,
    ITCH_GAME,
    STEAM_APP_BUILD_VDF,
    AWS_ACCOUNT_ID,
    AWS_REGION,
    ECR_REGIONS,
    ECS_CLUSTER,
)

GODOT_RELEASE_TARGETS = [
    "Linux/X11",
    "Windows Desktop",
    "macOS"
]


def cmd(args):
    res = subprocess.run(args, shell=True)


def main():
    commands = sys.argv[1:]
    command_map = {
        "build:game": build_game,
        "release:game": release_game,
        "build:mm": build_matchmaker,
        "restart:game": restart_gameservers,
        "restart:mm": restart_matchmaker,
    }

    for command in commands:
        func = command_map.get(command)
        if not func:
            print("invalid command: ", command)
            return
        func()


def build_game():
    version = datetime.datetime.utcnow().isoformat()
    open('version', 'w').write(version)

    for target in GODOT_RELEASE_TARGETS:
        cmd([GODOT_PATH, "--headless", "--export-release", target])


def release_game():
    itch_project = f"{ITCH_USER}/{ITCH_GAME}"
    ecr_url = f"{AWS_ACCOUNT_ID}.dkr.ecr.{AWS_REGION}.amazonaws.com"

    cmd([BUTLER_PATH, "login"])
    cmd([BUTLER_PATH, "push", "./Exports/Windows", f"{itch_project}:win"])
    cmd([BUTLER_PATH, "push", "./Exports/MacOS", f"{itch_project}:mac"])
    cmd([BUTLER_PATH, "push", "./Exports/Linux", f"{itch_project}:linux"])

    cmd(f".\\Steam\\builder\\steamcmd.exe +login {ITCH_USER} +run_app_build {STEAM_APP_BUILD_VDF} +exit")

    cmd(f"aws ecr get-login-password --region {AWS_REGION} | docker login --username AWS --password-stdin {ecr_url}")

    cmd("docker build -t hookshot-gameserver -f Server/dockerfiles/GameServer .")
    cmd(f"docker tag hookshot-gameserver:latest {ecr_url}/hookshot-gameserver:latest")
    cmd(f"docker push {ecr_url}/hookshot-gameserver:latest")


def build_matchmaker():
    ecr_url = f"{AWS_ACCOUNT_ID}.dkr.ecr.{AWS_REGION}.amazonaws.com"

    cmd(f"aws ecr get-login-password --region {AWS_REGION} | docker login --username AWS --password-stdin {ecr_url}")

    cmd("docker build -t hookshot-matchmaker -f Server/dockerfiles/Matchmaker .")
    cmd(f"docker tag hookshot-matchmaker:latest {ecr_url}/hookshot-matchmaker:latest")
    cmd(f"docker push {ecr_url}/hookshot-matchmaker:latest")


def restart_gameservers():
    _restart_task_family("hookshot-gameservers")


def restart_matchmaker():
    _restart_task_family("hookshot-matchmakers")


def _restart_task_family(family):
    for region in ECR_REGIONS:
        ecs = boto3.client("ecs", region_name=region)
        game_server_tasks = ecs.list_tasks(
            cluster=ECS_CLUSTER,
            family=family
        )["taskArns"]

        for task in game_server_tasks:
            ecs.stop_task(
                cluster=ECS_CLUSTER,
                task=task
            )


if __name__ == "__main__":
    main()