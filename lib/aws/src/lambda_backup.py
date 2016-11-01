import boto3
import datetime
import sys
import traceback


class LambdaBackup(object):
    def __init__(self, options):
        self.opts = options
        self.ec2 = boto3.client('ec2')
        self.failed_backups = []

    def backup(self):
        for i in self.__listInstances():
            if self.__isExcludedFromBackups(i):
                print "Skipping " + i['InstanceId']
                continue

            print "Backing up " + i['InstanceId']

            if not self.__backupInstance(i):
                # We'll only clean up existing backups for this instance if the backup run succeeded
                self.failed_backups.append(i['InstanceId'])
                print "Backup failed for " + i['InstanceId']

        self.__cleanup()

    def __listInstances(self):
        reservations = self.ec2.describe_instances()['Reservations']
        return sum([
                        [i for i in r['Instances']]
                        for r in reservations
                   ],
                   [])

    def __backupInstance(self, instance):
        for v in instance['BlockDeviceMappings']:
            if 'Ebs' not in v:
                continue

            today = datetime.datetime.now()
            if today.day == 0 and self.opts['retentionMonths']:
                runName = 'Monthly'
                expirationStamp = today + datetime.timedelta(days=(31 * self.opts['retentionMonths']))

            elif today.weekday() == 0 and self.opts['retentionWeeks']:
                runName = 'Weekly'
                expirationStamp = today + datetime.timedelta(days=(7 * self.opts['retentionWeeks']))

            else:
                runName = 'Daily'
                expirationStamp = today + datetime.timedelta(days=self.opts['retentionDays'])
            
            try:
                snapshot = self.ec2.create_snapshot(VolumeId=v['Ebs']['VolumeId'],
                                                    Description="%s backup of %s on instance %s" % (runName, v['DeviceName'], instance['InstanceId']),
                                                    DryRun=False)
                self.ec2.create_tags(Resources=[snapshot['SnapshotId']], Tags=[
                                                                                {'Key': 'ExpirationTime', 'Value': str(expirationStamp)},
                                                                                {'Key': 'InstanceId', 'Value': instance['InstanceId']},
                                                                                {'Key': 'CreatedBy', 'Value': 'LambdaBackup'}
                                                                              ])
            except:
                print traceback.format_exc()
                return False
            

            return True

    def __cleanup(self):
        print "Cleaning up old snapshots ..."
        snapshots = self.ec2.describe_snapshots(OwnerIds=['self'], Filters=[{
                                                                                'Name': 'tag:CreatedBy',
                                                                                'Values': ['LambdaBackup']
                                                                            }])['Snapshots']
        for s in snapshots:
            this_id = None
            this_exp_stamp = None

            for t in s['Tags']:
                if t['Key'] == 'InstanceId':
                    this_id = t['Value']
                if t['Key'] == 'ExpirationTime':
                    this_exp_stamp = datetime.datetime.strptime(t['Value'], "%Y-%m-%d %H:%M:%S.%f")

            if not this_id or \
               not this_exp_stamp or \
               this_id in self.failed_backups or \
               datetime.datetime.now() < this_exp_stamp:
                continue

            print "Will delete %s, expired on %s" % (s['Description'], this_exp_stamp)
            self.ec2.delete_snapshot(SnapshotId=s['SnapshotId'], DryRun=False)

    def __isExcludedFromBackups(self, instance):
        for t in instance['Tags']:
            if t['Key'] == 'Name' and t['Value'] in self.opts['excludeInstanceNames']:
                return True
            for exclItem in self.opts['excludeInstanceTags']:
                for exclTag, exclVal in exclItem.iteritems():
                    if t['Key'] == exclTag and t['Value'] == exclVal:
                        return True
        return False

def run_backup(event, context):
    job = LambdaBackup(options={
                                    # Configuration
                                    #
                                    # How many days before deleting daily snapshots
                                    "retentionDays": 3,
                                    
                                    # How many weeks before deleting weekly snapshots
                                    "retentionWeeks": 4,

                                    # How many months before deleting monthly snapshots
                                    "retentionMonths": 12,

                                    # List any instance names that should be excluded from backups
                                    "excludeInstanceNames": [""],

                                    # List any instance tags and values that should be excluded from backups
                                    "excludeInstanceTags": [{"LambdaBackupStrategy": "Never"}]
                                })

    job.backup()

if __name__ == '__main__':
    run_backup({}, {})
