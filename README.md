# Invalidate Cloudfront action

A GitHub Workflow Action which invalidates the given Cloudfront distribution paths.

## Usage

The sample workflow below illustrates a static site build and deploy.

```yaml
name: Build and Deploy
on:
  push:
    branches:
      - master

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - name: checkout
      uses: actions/checkout@master

    - name: setup node
      uses: actions/setup-node@v1
      with:
        node-version: '10.x'

    # Run the build script which populates the ./dist folder
    - name: build
      run: |
        yarn
        yarn run build

    # Merge ./dist into the 'gh-pages' branch (dist in this case)
    - name: update dist branch
      uses: peaceiris/actions-gh-pages@v2.3.1
      env:
        PERSONAL_TOKEN: ${{ secrets.ACCESS_TOKEN }}
        PUBLISH_BRANCH: dist
        PUBLISH_DIR: ./dist

    # Check out the new branch
    - name: checkout dist
      uses: actions/checkout@master
      with:
        ref: dist

    # Fix timestamps
    - name: restore timestamps
      uses: chetan/git-restore-mtime-action@release

    # Upload to S3
    - name: sync s3
      uses: jakejarvis/s3-sync-action@2fb81a9e9fea11e078587911c27754e42e6a6e88
      with:
        args: --exclude '.git*/*' --delete --follow-symlinks
      env:
        SOURCE_DIR: './'
        AWS_REGION: 'us-east-1'
        AWS_S3_BUCKET: ${{ secrets.AWS_S3_BUCKET }}
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

    # Invalidate Cloudfront (this action)
    - name: invalidate
      uses: chetan/invalidate-cloudfront-action@master
      env:
        DISTRIBUTION: ${{ secrets.DISTRIBUTION }}
        PATHS: '/index.html'
        AWS_REGION: 'us-east-1'
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

```

### AWS IAM Policy

In order to use this action, you will need to supply an access key pair which has, at minimum, the following permission:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "cloudfront:CreateInvalidation",
            "Resource": "arn:aws:cloudfront::<account id>:distribution/*"
        }
    ]
}
```

Note that cloudfront [does not support resource-level permissions](https://stackoverflow.com/a/44373795/1777780).
