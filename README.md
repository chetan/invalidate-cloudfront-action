# Invalidate AWS CloudFront action

A GitHub Workflow Action for invalidating CloudFront distribution paths

## Usage

```yaml
- name: Invalidate CloudFront
  uses: chetan/invalidate-cloudfront-action@v2
  env:
    DISTRIBUTION: ${{ secrets.DISTRIBUTION }}
    PATHS: "/index.html"
    AWS_REGION: "us-east-1"
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

See also a [sample workflow](./example.yml) which illustrates a static site
build and deploy.

## Configuration

| Param                 | Required? | Description                                                                                        |
| --------------------- | --------- | -------------------------------------------------------------------------------------------------- |
| PATHS                 | yes*      | A list of one or more space-separated paths to invalidate                                          |
| PATHS_FROM            | yes*      | Filename to read list of paths from                                                                |
| DISTRIBUTION          | yes       | CloudFront distribution ID to operate on, e.g., 'EDFDVBD6EXAMPLE'                                  |
| AWS_REGION            | yes       | AWS Region to operate in                                                                           |
| AWS_ACCESS_KEY_ID     | yes       | Access key with necessary permissions to invalidate objects in the target distribution (see below) |
| AWS_SECRET_ACCESS_KEY | yes       | Secret key                                                                                         |
| DEBUG                 | no        | When set to "1", prints the final awscli invalidation command for troubleshooting purposes         |

__Note__: *either* `PATHS` or `PATHS_FROM` is required. `PATHS_FROM` will
overwrite `PATHS` if both are set.

See also: [AWS CLI reference](https://docs.aws.amazon.com/cli/latest/reference/cloudfront/create-invalidation.html)

### Paths

Paths are passed directly to the aws cli `create-invalidation` command and so
must be a proper space-separated list of paths. Examples:

```sh
PATHS=/index.html
PATHS=/ /index.html /foo/bar/baz
```

Alternatively, you can write the list of files to invalidate to a file which
will then be slurped into the PATHS variable. This lets you use some other
method to dynamically generate the list of files based on the commit, etc.
Example workflow steps:

```yaml
- name: checkout dist
  uses: actions/checkout@master
  with:
    ref: dist
    # need at least 2 here so we can get a proper log in next step
    fetch-depth: 2

- name: get updated files
  run: |
    # allow grep to fail
    set +e
    FILES=$(git log --stat="1000" -1 | grep '|' | awk '{print "/"$1}' | grep -e '\.html$')
    set -e
    [ -z "$FILES" ] && touch .updated_files && exit 0
    for file in $FILES; do
      echo $file
      # add bare directory to list of updated paths when we see index.html
      [[ "$file" == *"/index.html" ]] && echo $file | sed -e 's/\/index.html$/\//'
    done | sort | uniq | tr '\n' ' ' > .updated_files

- name: invalidate
  uses: chetan/invalidate-cloudfront-action@v2
  env:
    PATHS_FROM: .updated_files
    AWS_REGION: 'us-east-1'
    DISTRIBUTION: ${{ secrets.DISTRIBUTION }}
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### AWS Credentials

The recommended way to pass AWS credentials to your GitHub actions is to use
[OpenID
Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).

Once configured, you can use the
[aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
action to properly authentication and supply AWS credentials to subsequent steps
in your workflow.

Note that your workflow will need the following permission when using OIDC:

```yaml
permissions:
  id-token: write
```

For a complete example, see the [workflow](./.github/workflows/tests.yml) in
this repository.

Also note that if you using the CloudFormation template from the aws repo above,
the 'thumbprint' shown in the example is out of date. I've included a [working
template](./docs/github-oidc.yaml) complete with the below IAM policy that
should work out of the box (as of 2022-01-27).

As an alternative, you may directly pass an access/secret key pair. See the
config section above.

### AWS IAM Policy

In order to use this action, you will need to supply credentials which have, at minimum, the following permission:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "cloudfront:CreateInvalidation",
            "Resource": "arn:aws:cloudfront::<account id>:distribution/<distribution ID>"
        }
    ]
}
```

## Self-hosted runners

A note regarding [self-hosted
runners](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners):

`V2` of the `invalidate-cloudfront-action` executes via a bash script on the
runner and requires the following additional tools:

- jq 1.6
- aws 1.x+
- tr
- date
- wget

Please ensure that they are available on your system or use V1 of the action,
which executes within a docker container.
