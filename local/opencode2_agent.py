"""OpenCode agent for images that already contain OpenCode 2."""

from dataclasses import replace

from harbor.agents.agent_auth_resolution import ProviderAccess
from harbor.agents.installed.opencode import OpenCode
from harbor.environments.base import BaseEnvironment


class PreinstalledOpenCode2(OpenCode):
    """Reuse the preinstalled CLI instead of installing opencode-ai 1.x."""

    MODEL_CONNECTION = replace(
        OpenCode.MODEL_CONNECTION,
        agent_provider_access=ProviderAccess(
            api_key_candidate_names=[
                "OPENCODE_API_KEY",
                "OPENROUTER_API_KEY",
                "OPENAI_API_KEY",
            ],
            base_url_candidate_names=[
                "OPENROUTER_BASE_URL",
                "OPENAI_BASE_URL",
                "OPENAI_API_BASE",
            ],
        ),
    )

    async def install(self, environment: BaseEnvironment) -> None:
        result = await environment.exec(command="opencode --version")
        if result.return_code != 0:
            raise RuntimeError("OpenCode 2 is not installed in the task image")
