'use strict';

const node_ssh = require('node-ssh');
const config = require('./config.json');
const path = require('path');
const scp2 = require('scp2');

class PerfServer {
  constructor(host, username, password) {
    this.host = host;
    this.username = username;
    this.password = password;
    this.ssh = new node_ssh();
    this.conn = this.ssh.connect(
      {host: host, username: username, password: password}
    );
  }

  async connect() {
    await this.conn.then(() => {
      console.info(`connect to ${this.host}`);
    }, (error) => {
      console.info(error);
    });
  }

  async installPackage(packages) {
    if (packages === null || !Array.isArray(packages)
      || packages.length === 0) {
      return;
    }
    await this.ssh.execCommand(`apt update; apt install -y ${packages.join(' ')}`)
      .then( result => {
        console.log(`STDOUT: ${result.stdout}`);
        console.log(`STDERR: ${result.stderr}`);
      });
  }

  async uploadFile(src, remote) {
    await new Promise( (resolve, reject) => {
      scp2.scp(src, {
        host: this.host,
        username: this.username,
        password: this.password,
        path: remote
      }, function(err) {
        if (err) {
          reject(err);
        } else {
          console.info(`uploaded to ${remote}`);
          resolve();
        }
      });
    });
  }

  async addUser(name) {
    await this.ssh.execCommand(`adduser  --disabled-password --gecos "" ${name}`);
    await this.ssh.execCommand(`mkdir ~${name}/.ssh; chmod 755 ~${name}/.ssh`);
    await this.ssh.execCommand(`chown ${name}:${name} -R ~${name}/.ssh`);
  }

  async addKeys(loc, name) {
    await this.ssh.execCommand(`cat ${loc} >> ~${name}/.ssh/authorized_keys`);
    await this.ssh.execCommand(`chown ${name}:${name} -R ~${name}/.ssh`);
  }

  async copyKeyAsUserKey(priv, pub, user) {
    await this.ssh.execCommand(`cp ${priv} ~${user}/.ssh/id_rsa`);
    await this.ssh.execCommand(`cp ${pub} ~${user}/.ssh/id_rsa.pub`);
    await this.ssh.execCommand(`chown ${user}:${user} -R ~${user}/.ssh`);
  }

  async exec(command) {
    await this.ssh.execCommand(command);
  }

  async disconnect() {
    await this.ssh.execCommand(`exit`)
      .then( result => {
        console.log(`STDOUT: ${result.stdout}`);
      });
    this.ssh.dispose();
  }
}

async function setup(config) {
  for (let one in config.servers) {
    console.info(`start to config server: ${one}`);
    let settings = config.servers[one];
    let server = new PerfServer(
      settings.ip, settings.username, settings.password);
    await server.connect();
    await server.installPackage(config.packages);
    for (let index = 0, length = config.users.length; index < length; index++) {
      let userInfo = config.users[index];
      await server.addUser(userInfo.name);
      if (userInfo['pub-key']) {
        await server.uploadFile(userInfo['pub-key'], '/root/tmp-key.pub')
        await server.addKeys('/root/tmp-key.pub', userInfo.name);
      }
      if (userInfo['priv-key']) {
        await server.uploadFile(userInfo['priv-key'], '/root/tmp-key')
      }
      if (userInfo['pub-key'] && userInfo['priv-key']) {
        await server.copyKeyAsUserKey('/root/tmp-key', '/root/tmp-key.pub', userInfo.name);
      }
      if (userInfo.sudoer && userInfo.sudoer === true) {
        await server.exec(`echo "${userInfo.name}  ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers`);
      }
      await server.exec(`rm -f /root/tmp-key.pub && rm -f /rot/tmp-key`);
    };
    await server.disconnect();
  }
}

setup(config);
