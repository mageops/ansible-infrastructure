const zlib = require('zlib'),
    https = require('https'),
    url = require('url');

const slackHook = url.parse(process.env.SLACK_HOOK_URL),
    channel = process.env.SLACK_CHANNEL;

function postToSlack(payload) {
    payload = JSON.stringify(payload);

    return new Promise((resolve, reject) => {
        let req = https.request({
            hostname: slackHook.hostname,
            path: slackHook.pathname,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload)
            }
        }).on('response', (res) => {
            if (res.statusCode !== 200) {
                return reject(new Error('Error ' + res.statusCode));
            }

            console.log('Posted to slack: ' + JSON.stringify(payload));

            resolve(res);
        });

        req.write(payload);
        req.end();
    });
}

function parseGroup(group) {
    const elements = group.split('/');

    if (elements.length < 4) {
        return {
            project: 'unknown',
            env: 'unknown'
        }
    }

    return {
        project: elements[1],
        env: elements[2],
        software: elements[3]
    };
}

function handleLogItem(data, project, env, software, link) {
    let message = data.message,
        errtype = software;

    if (software === 'php-fpm' || software === 'nginx') {
        errtype = 'PHP';
    }

    if (software === 'magento') {
        errtype = 'Magento';
    }

    if (message.length > 600) {
        message = message.substring(0, 600) + '\n[...]';
    }

    return postToSlack({
        "text": `:skull_and_crossbones: CRITICAL *${errtype}* Error on *${project}*-_${env}_: <${link}|See details here>`,
        "channel": channel,
        "username": "AWS",
        "icon_emoji": ":cloud:",
        "attachments": [
            {
                "color": "#D00000",
                "fields":[
                    {
                        "title": "Exception",
                        "value": message,
                        "short": false
                    }
                ]
            }
        ]
    });
}

function handleData(data) {
    let handled = [],
        group = data.logGroup,
        stream = data.logStream,
        groupData = parseGroup(group),
        project = groupData.project,
        env = groupData.env,
        software = groupData.software,
        region = process.env.AWS_DEFAULT_REGION,
        link = `https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#logEventViewer:group=${encodeURIComponent(group)};stream=${encodeURIComponent(stream)}`


    data.logEvents.forEach((item) => {
        handled.push(
            handleLogItem(
                item,
                project,
                env,
                software,
                link
            )
        );
    })

    return Promise.all(handled);
}

exports.handler = (event, context, done) => {
    let payload = new Buffer(event.awslogs.data, 'base64');

    zlib.gunzip(payload, (e, result) => {
        handleData(JSON.parse(result.toString('utf-8')), done).then(() => {
            done(null);
        }, (e) => {
            done(new Error(e));
        })
    });
};