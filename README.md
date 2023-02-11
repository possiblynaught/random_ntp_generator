# Random NTP Generator

Generates a randomized list of ipv4 addresses for hard coded ntp servers in US/North America. Uses time.nist.gov, US internet/tech companies, and pool.ntp.org (stratum 1 & 2) servers.

## USE

To use this generator, clone the repository, enter the repository, and run the *get_random_servers.sh* script:

```bash
git clone https://github.com/possiblynaught/random_ntp_generator.git
cd random_ntp_generator/
./get_random_servers.sh
```

Once run successfully, it will print the list of servers and save them to a file (*/tmp/random_ntp_servers.txt*). You can change this save location and the max number of servers to generate by editing the *OUTPUT_FILE* and *MAX_SERVERS* variables in the *get_random_servers.sh* script.

## INFO

T

## TODO

- [x] Add function to get pool.ntp.org servers
- [x] Finish script to choose random subset of servers
- [x] Finish README
- [x] Add function for getting google, facebook, apple, cloudflare, microsoft time servers
- [x] Add function for getting time from US universities
- [ ] Create script to install the ntp list for chrony, ntp, and openntpd
- [ ] Require ntp auth? remove openntpd?
- [ ] Option to use non-us/north america servers
