modules_enabled = {
    'roster'; -- Allow users to have a roster. Recommended ;)
    'saslauth'; -- Authentication for clients and servers. Recommended if you want to log in.
    'tls'; -- Add support for secure TLS on c2s/s2s connections
    'disco'; -- Service discovery

    'private'; -- Private XML storage (for room bookmarks, etc.)
    'vcard'; -- Allow users to set vCards

    'pep'; -- Enables users to publish their mood, activity, playing music and more
    'register'; -- Allow users to register on this server using a client and change passwords
}

allow_registration = true
c2s_require_encryption = false
authentication = 'internal_plain'

log = {'*console'}
data_path = '.prosody-data'

VirtualHost 'localhost'
VirtualHost(require('socket').dns.gethostname())

