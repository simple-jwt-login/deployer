# Deployer

This action will publish a plugin to WordPress.org.

Required Secrets:
```
SVN_USERNAME
SVN_PASSWORD
```

```yaml
jobs:
  run:
    # ... 
    steps:
        - name: Deploy to WordPress.org
          uses: simple-jwt-login/deployer@main
          with:
            plugin_folder: "simple-jwt-login"
            exlude: ".git, .gitignore, .github, tests/*"
            slug: "simple-jwt-login"
            username: ${{secrets.SVN_USERNAME}}
            password: ${{secrets.SVN_PASSWORD}}
            tag: ${{ github.ref_name }}
            assets_folder: "wordpress.org/assets"
            dry-run: true, # When pressent, it will not execute svn commit
```