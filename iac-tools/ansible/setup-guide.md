Ansible Configuration
- Use WSL Ubuntu
- sudo apt update
- sudo apt install -y ansible
- validate: ansible --version
- create a directory for ansible script
- copy the inventory.ini and playbook.yml
- test connectivity - ansible all -i inventory.ini -m ping
- run playbook  ansible-playbook -i inventory.ini playbook.yml

validate if clusters are all connected:
ansible -i inventory.ini control_planes -m command -a "kubectl get nodes"
