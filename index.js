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
    await server.installPackage(['xfsprogs', 'xfsdump']);
    await server.uploadFile(config.keys.pub, '/root/perf-key.pub')
    await server.uploadFile(config.keys.priv, '/root/perf-key')
    for (let index = 0, length = config.users.length; index < length; index++) {
      let user = config.users[index];
      await server.addUser(user);
      await server.addKeys('/root/perf-key.pub', user);
      await server.copyKeyAsUserKey('/root/perf-key', '/root/perf-key.pub', user);
      await server.exec(`echo "${user}  ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers`);
    };
    await server.disconnect();
  }
}

setup(config);
