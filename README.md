# Random NTP Generator

Generates a randomized list of ipv4 addresses for hard coded ntp servers in US/North America. Uses time.nist.gov and pool.ntp.org (stratum 1 & 2) servers.

## USE

To use this generator, clone the repository, enter the repository, and run the *get_random_servers.sh* script:

```bash
git clone https://github.com/possiblynaught/random_ntp_generator.git
cd random_ntp_generator/
./get_random_servers.sh
```

Once run successfully, it will print the list of servers and save them to a file (*/tmp/random_ntp_servers.txt*). You can change this save location and the max number of servers to generate by editing the *OUTPUT_FILE* and *MAX_SERVERS* variables in the *get_random_servers.sh* script.

## TODO

- [x] Add function to get pool.ntp.org servers
- [x] Finish script to choose random subset of servers
- [x] Finish README
- [ ] Create script to install the ntp list for chrony, ntp, and openntpd
- [ ] Add functions for getting google, facebook, apple, cloudflare, microsoft time servers
- [ ] Require ntp auth? remove openntpd?
- [ ] Option to use non-us/north america servers
