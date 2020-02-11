<p align="center">
  <img alt="MageSuite" width="211" src="https://avatars2.githubusercontent.com/u/56443641?s=200&v=4">
</p>

<p align="center">
  <em>Ansible-based infrastructure-as-code for hosting and deploying Magento-based shops.</em>
</p>

# Infrastructure Provisioning

## CI/CD Automation

**This code handles infrastucture provisioning, maintenance and deployment only**. 
This repository does not contain any CI/CD automation for building, testing or
running the provisioning itself. We do that internally with reusable Jenkins
pipelines (as libraries) - as this setup is very specific to our workflow we are 
not planning to open-source it in the near future.

## MageSuite ecosystem

Altough it's possible to use this code to host any Magento-based shop,
some features are only avaialble (and tailored for) [MageSuite](https://magesuite.io/) ecosystem.

## Cloud infrastructre

Currently the full feature set is only available when using AWS as the cloud platform, however, 
it's possible (and tested) to use this code to provision any CentOS 7 VM including local development environment. 

_PS There's also an [experimental docker container](https://github.com/mageops/docker-centos-systemd) which can 
be fully provisioned by this code and run a full CentOS installation like a VM. This is intended to be used 
only for local development though and not yet supported_.

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
  - Media stored on S3
  - Seamless image optimization via Lambda@Edge (with webp support)
- Support for file sharing across nodes via AWS EFS
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
- ... any many more!

<sup>1</sup> Needs at least 2 app nodes and requires certain MageSuite extensions. Also it might not be
possible depending on changes in relation to previous release in the code being deployed (DB migrations, ...).

## Initial open-source release

The code has been cleaned up and all commits squashed for the first public release.

The previous internal repository had **2000+ commits**, **300+ merge requests** created by
10+ contributors across **3+ years of development**.

The current state is a result of hundreds of hours of meetings, debugging, brainstorms
investigations and combined expertise of all our developers, PMs and clients. 

A lot of the solutions are tailored for solving real-world problems and use-cases that came
up when hosting and maintaining highly-customized Magento-based shops. The value of such
experience-based solutions cannot be overestimated. It wouldn't be possible to come up and 
design all of these tiny details form scratch without having went through the all of problems first-hand.

## Documentation

At the time of open source release most of the documentation was scattered 
across internal creativestyle services thus any leftovers have been removed 
to avoid confusion. New documentation will start appearing shortly as part 
of this repository succesively.


<p align="right">
<em>Brought to life by</em><br/>
<a href="https://creativestyle.pl">
	<img src="https://images.squarespace-cdn.com/content/59144053ff7c509585045a38/1494845103833-S34MR8ONLUWAXOKQSM7O/CS_logo_colour.png?format=500w&content-type=image%2Fpng" width="160"/>
</a>
</p>
