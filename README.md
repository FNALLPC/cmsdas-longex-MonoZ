# Setup

## Website for the CMSDAS MonoZ

To start, you can follow the directions below. A summmary of the plan for the MonoZ group at the Data Analysis School is can be found in the main website [https://https://cmsdas-longex-monoz.docs.cern.ch](https://https://cmsdas-longex-monoz.docs.cern.ch). The prior iteration at IIT Hyderabad can be found [here](https://cmsdas-long-mono-z-hyderabad.docs.cern.ch/)
At these guides you will also find introduction to the physics, and explanations on each step of the school. 

Finally, 

Welcome to CMS!

## Connecting to lxplus with tunnels
Choose a port such as 8099 and connect to lxplus. This port should be used for jupyter as well. You'll need a unique port compared to others connecting, so watch out for warnings it's taken
```
# LXPLUS
ssh -L localhost:8NNN:localhost:8NNN lxplus.cern.ch
# LPC
ssh -L localhost:8NNN:localhost:8NNN cmslpc-el9.fnal.gov

```

## Clone and run the setup once
```
# LXPLUS
mkdir <working_directory>
cd <working_directory>
git clone -b daslpc2026 git@github.com:FNALLPC/cmsdas-longex-MonoZ.git
sh cmsdas-longex-MonoZ/bootstrap.sh bash cern
# or for zsh shell
sh cmsdas-longex-MonoZ/bootstrap.sh zsh cern

# LPC
mkdir ~/nobackup/<working_directory>
cd ~/nobackup/<working_directory>
git clone -b daslpc2026 git@github.com:FNALLPC/cmsdas-longex-MonoZ.git
sh cmsdas-longex-MonoZ/bootstrap.sh bash lpc
# or for zsh shell
sh cmsdas-longex-MonoZ/bootstrap.sh zsh lpc
```

## Starting the environment
Execute the shell command to start up the container. Once inside, start jupyter lab and copy + paste the link into your browser
```
# LXPLUS
cd <working_directory>
# LPC
cd ~/nobackup/<working_directory>

# BASH
./bash-shell
# ZSH
./zsh-shell

# Finally...
jupyter lab --no-browser --port 8NNN
```
