package main

import (
	"context"
	"flag"
	"fmt"
	"maps"
	"os"
	"slices"
	"sort"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch/types"
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

type DashboardData struct {
	Usage                map[string]map[string]Metric `yaml:"usage"`
	TrustAdvisorRegional map[string]map[string]Metric `yaml:"trusted_advisor_regional"`
	TrustAdvisorGlobal   map[string]map[string]Metric `yaml:"trusted_advisor_global"`
}

type SupportedMetrics struct {
	Usage                map[string]Metric `yaml:"usage"`
	TrustAdvisorRegional map[string]Metric `yaml:"trusted_advisor_regional"`
	TrustAdvisorGlobal   map[string]Metric `yaml:"trusted_advisor_global"`
	DashboardData        DashboardData     `yaml:"dashboard_data"`
}

var (
	client              *cloudwatch.Client
	outputFile          string
	debugOutput         = false
	overwriteOutputFile = false
	// Some metric resources require a specific statistic
	usageMetricStatistics = map[string]map[string]string{
		"SNS": {
			"NumberOfMessagesPublishedPerAccount": "Sum",
		},
		"KMS": {
			"CryptographicOperationsRsa":       "Sum",
			"CryptographicOperationsSymmetric": "Sum",
		},
	}
	usageMetricDefaultStatistic = "Maximum"
)

func init() {
	flag.Usage = func() {
		fmt.Fprint(os.Stderr, "A tool to get a list of CloudWatch metrics that allow the monitoring of service quota limits. It writes a YAML file with a list of metrics from the AWS/Usage and AWS/TrustedAdvisor namespaces.\n\n")
		flag.PrintDefaults()
	}
	flag.StringVar(&outputFile, "output-file", "supported-metrics.yaml", "A file to write the supported metrics to")
	flag.BoolVar(&debugOutput, "debug", false, "Enable debug output")
	flag.BoolVar(&overwriteOutputFile, "overwrite", false, "Whether to overwrite the output file. Default behaviour is to append all metrics to the existing metrics in the file")
	flag.Parse()
}

func main() {
	if debugOutput {
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
	} else {
		zerolog.SetGlobalLevel(zerolog.InfoLevel)
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatal().Msgf("unable to load SDK config: %v", err)
	}

	client = cloudwatch.NewFromConfig(cfg)

	supportedMetrics := SupportedMetrics{
		Usage:                map[string]Metric{},
		TrustAdvisorRegional: map[string]Metric{},
		TrustAdvisorGlobal:   map[string]Metric{},
	}

	usageMetrics, err := getSupportedUsageMetrics()
	if err != nil {
		log.Fatal().Msg(err.Error())
	}
	supportedMetrics.Usage = usageMetrics

	TAMetricsRegional, TAMetricsGlobal, err := getSupportedTrustedAdvisorMetrics()
	if err != nil {
		log.Fatal().Msg(err.Error())
	}
	supportedMetrics.TrustAdvisorGlobal = TAMetricsGlobal
	supportedMetrics.TrustAdvisorRegional = TAMetricsRegional

	log.Info().Msgf("Supported metrics returned: %v (AWS/TrustedAdvisor regional), %v (AWS/TrustedAdvisor global),%v (AWS/Usage)", len(TAMetricsRegional), len(TAMetricsGlobal), len(usageMetrics))

	err = writeFile(outputFile, supportedMetrics)
	if err != nil {
		log.Fatal().Msgf("error writing file: %v", err)
	} else {
		log.Info().Msgf("Successfully wrote metrics to %s", outputFile)
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
		convertedMetricName := convertedMetric.GetId()

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

func getSupportedTrustedAdvisorMetrics() (regionalResult map[string]Metric, globalResult map[string]Metric, err error) {
	regionalResult = map[string]Metric{}
	globalResult = map[string]Metric{}

	metrics, err := getMetricsForNamespace(client, "AWS/TrustedAdvisor")
	if err != nil {
		return nil, nil, fmt.Errorf("error getting AWS/TrustedAdvisor metrics: %s", err.Error())
	}

	for _, metric := range metrics {
		convertedMetric := convertMetricType(metric)
		convertedMetric.Statistic = "Maximum"
		convertedMetricName := convertedMetric.GetId()

		if *metric.MetricName != "ServiceLimitUsage" {
			log.Debug().Msgf("Metric unsupported: %s", convertedMetricName)
			continue
		}

		val, ok := convertedMetric.Dimensions["Region"]
		if !ok {
			return nil, nil, fmt.Errorf("region key not found in AWS/TrustedAdvisor metric %s", convertedMetricName)
		}

		log.Debug().Msgf("Metric supported: %s", convertedMetricName)

		if val == "-" {
			globalResult[convertedMetricName] = convertedMetric
		} else {
			regionalResult[convertedMetricName] = convertedMetric
		}
	}

	return regionalResult, globalResult, nil
}

func getMetricsForNamespace(client *cloudwatch.Client, namespace string) ([]types.Metric, error) {
	var metrics []types.Metric
	input := &cloudwatch.ListMetricsInput{
		Namespace: aws.String(namespace),
	}

	paginator := cloudwatch.NewListMetricsPaginator(client, input, func(o *cloudwatch.ListMetricsPaginatorOptions) {})
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(context.TODO())
		if err != nil {
			return nil, err
		}
		metrics = append(metrics, page.Metrics...)
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
		StartTime:     aws.Time(time.Now().Add(-1 * time.Hour)),
		EndTime:       aws.Time(time.Now()),
		MaxDatapoints: aws.Int32(1),
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
	if overwriteOutputFile || !fileExists(filePath) {
		err := metrics.WriteYamlFile(filePath)
		if err != nil {
			return err
		}
		log.Info().Msgf("Metrics written: %v (AWS/TrustedAdvisor regional), %v (AWS/TrustedAdvisor global),%v (AWS/Usage)", len(metrics.TrustAdvisorRegional), len(metrics.TrustAdvisorGlobal), len(metrics.Usage))
		return nil
	}

	existingMetrics := SupportedMetrics{}
	existingData, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("error reading existing file: %w", err)
	}
	if err := yaml.Unmarshal(existingData, &existingMetrics); err != nil {
		return fmt.Errorf("error unmarshalling existing YAML: %w", err)
	}

	log.Info().Msgf("Existing metrics found: %v (AWS/TrustedAdvisor regional), %v (AWS/TrustedAdvisor global),%v (AWS/Usage)", len(existingMetrics.TrustAdvisorRegional), len(existingMetrics.TrustAdvisorGlobal), len(existingMetrics.Usage))

	metrics.MergeMetrics(existingMetrics)
	err = metrics.WriteYamlFile(filePath)
	if err != nil {
		return err
	}

	return nil
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func (m *Metric) GetId() string {
	result := fmt.Sprintf("%s-%s-", m.Namespace, m.MetricName)

	dimensionKeys := slices.Collect(maps.Keys(m.Dimensions))
	sort.StringSlice(dimensionKeys).Sort()
	for _, k := range dimensionKeys {
		if k == "Region" && m.Namespace == "AWS/TrustedAdvisor" {
			continue
		}
		result = fmt.Sprintf("%s%s", result, m.Dimensions[k])
	}

	result = strings.ReplaceAll(result, "/", "")
	result = strings.ReplaceAll(result, " ", "")
	result = strings.ReplaceAll(result, "(", "")
	result = strings.ReplaceAll(result, ")", "")

	if len(result) > 230 {
		result = result[:230]
	}

	return result
}

func (m *Metric) SetUsageMetricStatistic() {
	if m.Namespace != "AWS/Usage" {
		return
	}

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

func (s *SupportedMetrics) generateDashboardData() {
	s.DashboardData.Usage = make(map[string]map[string]Metric)
	s.DashboardData.TrustAdvisorGlobal = make(map[string]map[string]Metric)
	s.DashboardData.TrustAdvisorRegional = make(map[string]map[string]Metric)

	for id, metric := range s.Usage {
		serviceName := metric.Dimensions["Service"]
		if _, ok := s.DashboardData.Usage[serviceName]; !ok {
			s.DashboardData.Usage[serviceName] = make(map[string]Metric)
		}
		s.DashboardData.Usage[serviceName][id] = metric
	}

	for id, metric := range s.TrustAdvisorRegional {
		serviceName := metric.Dimensions["ServiceName"]
		if _, ok := s.DashboardData.TrustAdvisorRegional[serviceName]; !ok {
			s.DashboardData.TrustAdvisorRegional[serviceName] = make(map[string]Metric)
		}
		s.DashboardData.TrustAdvisorRegional[serviceName][id] = metric
	}

	for id, metric := range s.TrustAdvisorGlobal {
		serviceName := metric.Dimensions["ServiceName"]
		if _, ok := s.DashboardData.TrustAdvisorGlobal[serviceName]; !ok {
			s.DashboardData.TrustAdvisorGlobal[serviceName] = make(map[string]Metric)
		}
		s.DashboardData.TrustAdvisorGlobal[serviceName][id] = metric
	}
}

func (s *SupportedMetrics) WriteYamlFile(filePath string) error {
	s.generateDashboardData()

	yamlData, err := yaml.Marshal(s)
	if err != nil {
		return fmt.Errorf("error marshalling YAML: %w", err)
	}

	err = os.WriteFile(filePath, yamlData, 0644)
	if err != nil {
		return fmt.Errorf("error writing file '%s': %w", filePath, err)
	}

	return nil
}

func (s *SupportedMetrics) MergeMetrics(newMetrics SupportedMetrics) {
	for k, v := range newMetrics.Usage {
		s.Usage[k] = v
	}
	for k, v := range newMetrics.TrustAdvisorGlobal {
		s.TrustAdvisorGlobal[k] = v
	}
	for k, v := range newMetrics.TrustAdvisorRegional {
		s.TrustAdvisorRegional[k] = v
	}
}
