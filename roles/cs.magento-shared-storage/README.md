Magento Shared Storage Meta-role
================================

This role analyzes environment configuration and sets up underlying
shared file storage mechanisms by calling appropriate roles.

Currently both the resource setup and mounts happen in the same code
so this role should be ran on app node as it will set up the mounts too.