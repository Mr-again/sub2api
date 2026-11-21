# Company deployment branch

`origin` is the company fork. Keep its `main` available for upstream sync.
`codex/company-deploy` starts at a tagged upstream release and contains the
company Compose override and the Windows release build script.

To sync upstream commits and explicitly advance the deployment branch:

```sh
gh repo sync Mr-again/sub2api --source Wei-Shaw/sub2api --branch main
git fetch upstream --tags
git switch codex/company-deploy
git merge vNEXT
git push origin codex/company-deploy
```

Replace `vNEXT` with a reviewed upstream release tag. To include an upstream
commit before a release, merge its reviewed SHA in place of the tag. The
release script packages the Linux build and a SHA-256 checksum. Run
`pwsh -NoProfile -File deploy/Build-CompanyRelease.ps1 -Version X.Y.Z -Publish`
from the deployment branch. Verify the release checksum, package the binary
with the matching Sub2API runtime image, and update `SUB2API_IMAGE`.
Use the upstream local-directory Compose file and the company override together.
Keep deployment environment files, database volumes, and credentials off Git.
