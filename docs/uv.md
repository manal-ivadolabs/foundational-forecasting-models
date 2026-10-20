# New to uv

**What is it?** Python packaging and dependency management made easy

**Why?** Replace `Pip` and `conda` and ensures that `if it works on my machine, it works on your machine`.

**Why not poetry?** It is much faster and also handles installation of python versions.



## pyproject.toml
uv will add dependencies and manage dependency groups in this file.

Here is an example of a `pyproject.toml` file:

```toml title="pyproject.toml"
[project]
dependencies = [
    "pandas>=2.2.3",
]

[dependency-groups]
test = [
    "coverage>=7.6.10",
]
```

`dependencies` are the main dependencies of the project. `dependency-groups` are groups that can optionally be installed. For example, `test` is a group that contains dependencies for testing.

## Basic commands

- `uv sync`: create a `.venv` folder and installs the dependencies.
- `uv add <package>`: equivalent to `pip install` to install a package. After installing the package, uv will update the `pyproject.toml` file and the `uv.lock` file.

> [!NOTE]
> uv will first check that all packages and their dependencies that are in the project are compatible with each other. This means that uv will try to find a combination of package versions that satisfies all the version requirements / restrictions of all packages in the project. If such a combination is found, uv generates / updates the `uv.lock` file that "pins" these exact versions.

Here is an example on how to add and install packages
```Bash
uv add prek --group dev
uv add sphinx --group docs
uv add pytest --group test

# then one can install the base requirements by running
uv sync
# or including a specific group
uv sync --group test
# or including all groups
uv sync --all-groups
```

- `uv remove <package>`: similar to `pip uninstall` to uninstall a package. After uninstalling the package, uv will update the `pyproject.toml` file and the `uv.lock` file.

- `uv run <command>`: allows running command within the local virtual environment.

## Handle Python versions
uv can also install a specific python version.

```bash
uv python install 3.12.8
```

> [!NOTE]
> The repo comes with a `.python-version` file that specifies the python version to use. It also comes with a `Makefile` that takes care of installing all of this for you.

## Prek hooks
uv offers a prek hook that ensures the lock file is up to date at commit time.

```yaml
  - repo: https://github.com/astral-sh/uv-pre-commit
    rev: 0.5.21
    hooks:
      - id: uv-lock
```
