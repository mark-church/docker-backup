# Docker EE Backup Tool
A tool that can be used to automate and schedule regular backups of UCP and DTR.

### Directions
Run this tool on a UCP controller. It will take both UCP and DTR backups sequentially and then save the backups to the current working directory of the UCP controller.

### Conf File Format
```
USERNAME=admin	
PASSWORD=password
UCP_URL=1.1.1.1
DTR_URL=2.2.2.2
```

### Run
```
docker run --rm -it \
-v /var/run/docker.sock:/var/run/docker.sock \
-v "$(pwd)":/var/docker-backup \
--env-file conf.env \
chrch/docker-backup:latest
```

Tested on:
- UCP 2.1, 2.2
- DTR 2.1, 2.2, 2.3
- Engine 17.06