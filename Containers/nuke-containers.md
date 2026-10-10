If the verification list at the end shows a binary as “STILL PRESENT”, it came from somewhere other than apt. Run command -v docker to see the path and delete that file by hand.

To restore install Docker again, then extract the backup:

```

sudo tar -xzf ~/container-volume-backup-*/docker-volumes.tar.gz -C /var/lib/docker

```

