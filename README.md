# WordPress Plugin Deployer [BETA]

A GitHub Action to automate the deployment of a WordPress plugin to the WordPress.org Plugin Repository.

## 🚀 Features

- Deploys a WordPress plugin to WordPress.org via SVN.
- Supports tagging and asset management.
- Allows excluding unnecessary files from deployment.
- Dry-run mode for testing before committing changes.

## 🔑 Required Secrets

To use this action, add the following secrets to your repository:

- `SVN_USERNAME` – Your WordPress.org username.
- `SVN_PASSWORD` – Your WordPress.org password.

## 🛠 Usage

```yaml
name: Deploy WordPress Plugin

on:
  push:
    tags:
      - "v*"  # Deploy on versioned tags

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3
        
      - name: Deploy to WordPress.org
        uses: simple-jwt-login/deployer@main
        with:
          plugin_folder: "simple-jwt-login"
          exclude: ".git, .gitignore, .github, tests/*"
          slug: "simple-jwt-login"
          username: ${{ secrets.SVN_USERNAME }}
          password: ${{ secrets.SVN_PASSWORD }}
          tag: ${{ github.ref_name }}
          assets_folder: "wordpress.org/assets"
          commit_message: "Release plugin"
          dry-run: true  # When present, it will not execute svn commit
```

## 📂 Inputs

| Name             | Description                                                | Required  |               Default             |
| ---------------- | ---------------------------------------------------------- | --------  | --------------------------------- |
| `plugin_folder`  | The directory of your WordPress plugin.                    | ✅ Yes    | /                                 |
| `exclude`        | Files or folders to exclude from deployment.               | ❌ No     | .git,.github, .gitignore          |
| `slug`           | The plugin's slug on WordPress.org.                        | ✅ Yes    | -                                 |
| `username`       | Your WordPress.org username (from secrets).                | ✅ Yes    | -                                 |
| `password`       | Your WordPress.org password (from secrets).                | ✅ Yes    | -                                 |
| `tag`            | The tag name for the release.                              | ❌ No     | -                                 |
| `assets_folder`  | Directory for WordPress.org assets (e.g., banners, icons). | ❌ No     | -                                 |
| `dry-run`        | If `true`, runs without committing changes.                | ❌ No     | false                             |  
| `commit-message` | A custom commit message                                    | ❌ No     | Plugin Update from GitHub actions | 

## 🔄 How It Works

1. Checks out the repository.
2. Copies the plugin files to a temporary directory.
3. Removes excluded files.
4. Tags and updates the plugin in the WordPress.org SVN repository.
5. Updates plugin assets if provided.
6. Commits changes unless `dry-run` is enabled.

## 📝 Notes

- Make sure your plugin follows WordPress.org [plugin guidelines](https://developer.wordpress.org/plugins/wordpress-org/).
- Always test your deployment using `dry-run: true` before a real release.

## 🤝 Contributing

Feel free to open issues or submit pull requests to improve this action.

## 📜 License

This project is licensed under the [MIT License](https://github.com/simple-jwt-login/deployer/blob/main/LICENSE).

