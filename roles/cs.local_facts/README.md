# Manage ansible local facts easily

## Persist new or updated facts

```yaml
- name: Save multiple facts at once using handler
  set_fact:
    ansible_local: "{{ ansible_local | combine(new_facts) }}"
  vars:
    new_facts:
      local_fact: "{{ updated_local_fact_value }}"
  # Make sure to trigger the handler as set_fact is never changed
  changed_when: true
  notify: Save local facts
```
