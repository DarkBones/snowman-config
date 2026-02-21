# Adding a New Machine to Snowman Taskserver

This assumes:

* Taskserver is already running on your Snowman host
* `/var/lib/taskserver` is the data dir
* Server CA + server certs already exist
* Port 53589 is reachable
* You are using strict TLS

---

## 1. On the Server (rpi4)

### 1.1 Create org (only once ever)

Skip if it already exists.

```
sudo TASKDDATA=/var/lib/taskserver taskd add org bas
```

---

### 1.2 Create a user for the new machine

Example: machine name `laptop`

```
sudo TASKDDATA=/var/lib/taskserver taskd add user bas laptop
```

You will get:

```
New user key: <UUID>
```

Copy this UUID. You will need it.

---

### 1.3 Generate client certificate

```
sudo sh -c '
  cd /var/lib/taskserver/pki &&
  ./generate.client laptop
'
```

This creates:

```
/var/lib/taskserver/pki/laptop.cert.pem
/var/lib/taskserver/pki/laptop.key.pem
```

---

### 1.4 Install the certificate into the user directory

Find the user UUID directory:

```
sudo ls /var/lib/taskserver/orgs/bas/users
```

It will look like:

```
<UUID>
```

Then:

```
sudo cp /var/lib/taskserver/pki/laptop.cert.pem \
  /var/lib/taskserver/orgs/bas/users/<UUID>/cert.pem

sudo chown -R taskd:taskd /var/lib/taskserver/orgs
sudo chmod -R 700 /var/lib/taskserver/orgs
```

This step is critical.
If the cert is not inside the UUID folder as `cert.pem`, authentication will fail.

---

### 1.5 Restart server

```
sudo systemctl restart taskserver
```

Server side is done.

---

## 2. On the New Machine (Client)

### 2.1 Install Taskwarrior

Nix:

```
nix profile install nixpkgs#taskwarrior3
```

Or your Snowman package set.

---

### 2.2 Copy certificates from server

Copy:

* CA cert
* client cert
* client key

```
ssh bas@rpi4 "sudo cat /var/lib/taskserver/keys/ca.cert" > ~/.task/keys/ca.cert.pem
ssh bas@rpi4 "sudo cat /var/lib/taskserver/pki/laptop.cert.pem" > ~/.task/keys/laptop.cert.pem
ssh bas@rpi4 "sudo cat /var/lib/taskserver/pki/laptop.key.pem"  > ~/.task/keys/laptop.key.pem
```

Secure permissions:

```
chmod 600 ~/.task/keys/laptop.key.pem
chmod 644 ~/.task/keys/laptop.cert.pem
chmod 644 ~/.task/keys/ca.cert.pem
```

---

### 2.3 Configure Taskwarrior

```
task config taskd.server 100.126.175.104:53589
task config taskd.credentials bas/laptop/<UUID>
task config taskd.certificate ~/.task/keys/laptop.cert.pem
task config taskd.key ~/.task/keys/laptop.key.pem
task config taskd.ca ~/.task/keys/ca.cert.pem
task config taskd.trust strict
```

Use the UUID from step 1.2.

---

### 2.4 Initialize sync

```
task sync init
```

You should see:

```
Sync successful.
```

---

# Mental Model (So You Never Debug This Again)

Taskserver authentication requires:

1. Correct org
2. Correct user
3. Correct UUID
4. Client cert signed by the same CA
5. That exact client cert placed inside:
   `/var/lib/taskserver/orgs/<org>/users/<UUID>/cert.pem`
6. Correct ownership (taskd)
7. Correct permissions
8. Matching credentials in `.taskrc`

If even one of these mismatches →
`Auth failure: org 'bas' user 'bas' bad key`

That error is never random. It is always structural mismatch.
