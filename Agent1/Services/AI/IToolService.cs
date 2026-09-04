using System.Collections.Generic;
using System.Threading.Tasks;
using Agent1.Models;

namespace Agent1.Services
{
    public interface IToolService
    {
        Task<ToolPlan> AnalyzeAndPlanToolsAsync(string userInput, string history);
        Task<Dictionary<string, string>> ExecuteToolsAsync(ToolPlan plan, string userInput);

        /// <summary>仅按 KeywordTriggers 规划，不调用 LLM。供 SK FC 失败后的快速兜底。</summary>
        ToolPlan PlanToolsByKeywords(string userInput)
        {
            return new ToolPlan { NeedsTools = false };
        }
    }
}