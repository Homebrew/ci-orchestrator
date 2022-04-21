# Homebrew CI Orchestrator

This is the backend system we're experimenting to listen for workflow jobs and deploy ephemeral VMs to run them.

It is not designed for usage outside of Homebrew. It is also very much experimental at this stage, and likely prone to many edge cases.

The system is designed to run on a single node and does not support scaling beyond that (this is not a problem for Homebrew's CI scale).

Reliability (not crashing) is heavily prioritised over code style, so you may see a few crimes such as catch-all `rescue` blocks. Threads and mutexes are heavily (ab)used given the somewhat slow nature of some operations like VM deployment paired with the uncertainty of how much concurrency the Orka API supports, along with all the HTTP client request code on the way there (with concurrency, if it's not explicitly stated as supported, it's usually best to assume it isn't). Safety first for now.

If you use MacStadium Orka, you may be interested in our [Ruby gem](https://github.com/Homebrew/orka_api_client) for interfacing with the Orka API. This project uses that gem extensively.
