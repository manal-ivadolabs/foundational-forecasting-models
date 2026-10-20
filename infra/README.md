# Infrastructure

> [!WARNING]
> Before adding a component, check if it already exists in [tempeh](https://github.com/ivado-labs/tempeh).
We use [OpenTofu](https://opentofu.org/docs/) which is a fork of Terraform that is open-source, community-driven, and managed by the Linux Foundation.

## Recommended Practices

- **Use one folder per environment** to maintain your infrastructure individually.
- **Adopt three primary environments**: `dev`, `qa`, and `prod`.
- **Organize your modules** by placing them inside a `modules` directory and importing them in `main.tf`.

You can explore the example files provided, which adhere to these recommendations.

## Usage

As an exemple, if you want to deploy only `dev`, you have to run:

```shell
cd dev
tofu apply
```
