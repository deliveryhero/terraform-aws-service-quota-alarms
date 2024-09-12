package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch/types"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"gopkg.in/yaml.v3"
)

type Metric struct {
	Namespace  string            `yaml:"namespace"`
	MetricName string            `yaml:"metric_name"`
	Statistic  string            `yaml:"statistic"`
	Dimensions map[string]string `yaml:"dimensions"`
}

type SupportedMetrics struct {
	UsageMetrics        map[string]Metric `yaml:"usage_metrics"`
	TrustAdvisorMetrics map[string]Metric `yaml:"trusted_advisor_metrics"`
}

var (
	client         *cloudwatch.Client
	configFilePath string
	debugOutput    = false
	// Some metric resources require a specific statistic
	usageMetricStatistics = map[string]map[string]string{
		"SNS": {
			"NumberOfMessagesPublishedPerAccount": "Sum",
		},
	}
	usageMetricDefaultStatistic = "Maximum"
)

func init() {
	flag.Usage = func() {
		fmt.Fprint(os.Stderr, "A tool to get a list of CloudWatch metrics that allow the monitoring of service quota limits. It writes a YAML file with a list of metrics from the AWS/Usage and AWS/TrustedAdvisor namespaces.\n\n")
		flag.PrintDefaults()
	}
	flag.StringVar(&configFilePath, "config-file", "supported-metrics.yaml", "A file to write the supported metrics to")
	flag.BoolVar(&debugOutput, "debug", false, "Enable debug output")
	flag.Parse()
}

func main() {
	if debugOutput {
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatal().Msgf("unable to load SDK config: %v", err)
	}

	client = cloudwatch.NewFromConfig(cfg)

	supportedMetrics := SupportedMetrics{
		UsageMetrics:        map[string]Metric{},
		TrustAdvisorMetrics: map[string]Metric{},
	}

	usageMetrics, err := getSupportedUsageMetrics()
	if err != nil {
		log.Fatal().Msg(err.Error())
	}
	supportedMetrics.UsageMetrics = usageMetrics

	trustedAdvisorMetrics, err := getSupportedTrustedAdvisorMetrics()
	if err != nil {
		log.Fatal().Msg(err.Error())
	}
	supportedMetrics.TrustAdvisorMetrics = trustedAdvisorMetrics

	err = writeFile(configFilePath, supportedMetrics)
	if err != nil {
		log.Fatal().Msgf("error writing file: %v", err)
	} else {
		log.Info().Msgf("Successfully wrote supported metrics to %s", configFilePath)
	}
}

func getSupportedUsageMetrics() (map[string]Metric, error) {
	result := map[string]Metric{}

	metrics, err := getMetricsForNamespace(client, "AWS/Usage")
	if err != nil {
		return nil, fmt.Errorf("error getting AWS/Usage metrics: %s", err.Error())
	}

	for _, metric := range metrics {
		convertedMetric := convertMetricType(metric)
		convertedMetricName := convertedMetric.GenerateNiceName()

		if metricSupportsServiceQuotaFunction(metric) {
			log.Debug().Msgf("Metric supported: %s", convertedMetricName)
			convertedMetric.SetUsageMetricStatistic()
			result[convertedMetricName] = convertedMetric
		} else {
			log.Debug().Msgf("Metric unsupported: %s", convertedMetricName)
		}
	}

	return result, nil
}

func getSupportedTrustedAdvisorMetrics() (map[string]Metric, error) {
	result := map[string]Metric{}

	metrics, err := getMetricsForNamespace(client, "AWS/TrustedAdvisor")
	if err != nil {
		return nil, fmt.Errorf("error getting AWS/TrustedAdvisor metrics: %s", err.Error())
	}

	for _, metric := range metrics {
		convertedMetric := convertMetricType(metric)
		convertedMetricName := convertedMetric.GenerateNiceName()

		if *metric.MetricName == "ServiceLimitUsage" {
			log.Debug().Msgf("Metric supported: %s", convertedMetricName)
			result[convertedMetricName] = convertedMetric
		} else {
			log.Debug().Msgf("Metric unsupported: %s", convertedMetricName)
		}
	}

	return result, nil
}

func getMetricsForNamespace(client *cloudwatch.Client, namespace string) ([]types.Metric, error) {
	var metrics []types.Metric
	var nextToken *string

	for {
		input := &cloudwatch.ListMetricsInput{
			Namespace: aws.String(namespace),
			NextToken: nextToken,
		}

		output, err := client.ListMetrics(context.TODO(), input)
		if err != nil {
			return nil, err
		}

		metrics = append(metrics, output.Metrics...)

		nextToken = output.NextToken
		if nextToken == nil {
			break
		}
	}

	log.Debug().Msgf("Got %v metrics for namespace: %s", len(metrics), namespace)

	return metrics, nil
}

func convertMetricType(input types.Metric) Metric {
	result := Metric{
		Dimensions: map[string]string{},
	}

	result.MetricName = *input.MetricName
	result.Namespace = *input.Namespace

	for _, d := range input.Dimensions {
		result.Dimensions[*d.Name] = *d.Value
	}

	return result
}

func metricSupportsServiceQuotaFunction(metric types.Metric) bool {
	input := &cloudwatch.GetMetricDataInput{
		MetricDataQueries: []types.MetricDataQuery{
			{
				Id: aws.String("m1"),
				MetricStat: &types.MetricStat{
					Metric: &types.Metric{
						MetricName: aws.String(*metric.MetricName),
						Namespace:  aws.String(*metric.Namespace),
						Dimensions: metric.Dimensions,
					},
					Period: aws.Int32(300),
					Stat:   aws.String("Sum"),
				},
			},
			{
				Id:         aws.String("e1"),
				Expression: aws.String("m1/SERVICE_QUOTA(m1)*100"),
			},
		},
		StartTime: aws.Time(time.Now().Add(-1 * time.Hour)),
		EndTime:   aws.Time(time.Now()),
	}

	_, err := client.GetMetricData(context.TODO(), input)
	if err != nil {
		if strings.Contains(err.Error(), "There is no service quota associated to this metric") || strings.Contains(err.Error(), "does not support quota retrieval for resource") {
			return false
		} else {
			fmt.Printf("error getting metric data: %s", err.Error())
			return false
		}
	}

	return true
}

func writeFile(filePath string, metrics SupportedMetrics) error {
	yamlData, err := yaml.Marshal(metrics)
	if err != nil {
		return fmt.Errorf("error marshalling YAML: %w", err)
	}

	return os.WriteFile(filePath, yamlData, 0644)
}

func (m *Metric) GenerateNiceName() string {
	result := fmt.Sprintf("%s-%s-", m.Namespace, m.MetricName)

	for _, v := range m.Dimensions {
		result = fmt.Sprintf("%s%s", result, v)
	}

	result = strings.ReplaceAll(result, "/", "")
	result = strings.ReplaceAll(result, " ", "")

	if len(result) > 230 {
		result = result[:230]
	}

	return result
}

func (m *Metric) SetUsageMetricStatistic() {
	_, ok := m.Dimensions["Service"]
	if !ok {
		return
	}

	_, ok = usageMetricStatistics[m.Dimensions["Service"]]
	if ok {
		metricStatistic, ok := usageMetricStatistics[m.Dimensions["Service"]][m.Dimensions["Resource"]]
		if ok {
			m.Statistic = metricStatistic
		}
	}

	if m.Statistic == "" {
		m.Statistic = usageMetricDefaultStatistic
	}
}
