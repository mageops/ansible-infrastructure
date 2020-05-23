# Infrastructure Provisioning

## CI/CD Automation

**This code handles infrastucture provisioning, maintenance and deployment only**.
This repository does not contain any CI/CD automation for building, testing or
running the provisioning itself. CI/CD is done in ... (TBD).

## Feature highlights

- Out-of-the-box autoscaling
- Zero-downtime deployments<sup>1</sup>
  - Nodes are warmed up when new code is being deployed before being attached
    to the varnish load-balancer to avoid cache generation penalty after traffic hit
- Varnish caching tailored for Magento with multiple configurable custom features
- Built-in support for elasticsearch / [ElasticSuite](https://github.com/Smile-SA/elasticsuite)
- Redis Magento cache backend with
  - Separate redis instance for session storage
- Customizable multi-website / multi-shop deployments
- Letsencrypt certificates support
- Cloudfront CDN
  - Media stored and shared across nodes using AWS EFS or AWS S3 (and possible plain NFS soonish)
  - Seamless image optimization via Lambda@Edge (with webp support)
- Support for arbitrary file sharing across nodes via AWS EFS
- Per path pattern customizable PHP limits
- Customizable request throttling (rate-limiting)
- On-demand import instance
  - EC2 instance started for scheduled imports automatically and terminated
    once the import is finished
  - Allows to use a different instance type for heavy scheduled imports
    and perform them without disrupting the site performance for end-users
- Customizable rules for routing traffic to separate set of special purpose extra-instances
  - Routing rules based on user-agent and request path patterns
  - Useful for processing heavy workloads without disrupting shop performance (e.g. ERP Magento API integrations)
- Magento queue consumers support with RabbitMQ and supervisord
- Logs pushed to CloudWatch with slack notifications for critical errors
- VPC and SG-based network communication rules allowing internal service communication
  strictly on a need-to basis
- Language and country-based redirects
- On-demand PHP debugging on production without affecting the shop's performance or configuration
- Advanced JavaScript Bundling support (via [Dockerized](https://github.com/mageops/magesuite-baler) AMD module bundler / preloader - [Baler](https://github.com/magento/baler))
- ... any many more!

<sup>1</sup> Needs at least 2 app nodes and requires certain MageSuite extensions. Also it might not be
possible depending on changes in relation to previous release in the code being deployed (DB migrations, ...).

# Development

Requirements:

- python 2.7

After you have them, run:

```sh
pip install -r requirements-python.txt
```
